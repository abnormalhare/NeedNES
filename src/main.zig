const std = @import("std");

const SDL = @import("render/sdl.zig");
const ImGui = @import("render/imgui.zig");

const RenderState = @import("global.zig").RenderState;
const TickType = @import("global.zig").TickType;

const Motherboard = @import("motherboard.zig").Motherboard;
const CPU = @import("cpu/cpu.zig").CPU;
const Inst = @import("cpu/instructions.zig");

const AppState = enum { Idle, Running };

const instructions: [0x100]*const fn (*CPU) void = blk: {
    @setEvalBranchQuota(100000);
    var arr: [0x100]*const fn (*CPU) void = undefined;

    for (0..0x100) |i| {
        const name = std.fmt.comptimePrint("op_{X:0>2}", .{i});
        if (!@hasDecl(Inst, name)) {
            arr[i] = @field(Inst, "op_none");
        } else {
            arr[i] = @field(Inst, name);
        }
    }
    break :blk arr;
};

pub fn call_instruction(instr: u8, cpu: *CPU) void {
    instructions[instr](cpu);
}

var render_states: std.ArrayList(RenderState) = undefined;
var motherboard: Motherboard = undefined;
var app_state: AppState = .Idle;
var rom_to_load: ?[:0]const u8 = null;

pub fn process_args(alloc: std.mem.Allocator) !?[:0]const u8 {
    var args = try std.process.ArgIterator.initWithAllocator(alloc);
    defer args.deinit();

    _ = args.skip();
    return args.next();
}

fn run_idle(alloc: std.mem.Allocator) !void {
    while (true) {
        _ = ImGui.process_events();

        for (render_states.items) |*state| {
            try SDL.back_render(state);
            if (try ImGui.render(alloc, state, &rom_to_load)) |new_state| {
                try render_states.append(alloc, new_state);
            }
            try SDL.render(alloc, state);
        }

        if (rom_to_load) |rom| {
            _ = rom;
            app_state = .Running;
            break;
        }
    }
}

fn run_running(alloc: std.mem.Allocator) !void {
    motherboard.power();

    try motherboard.load_rom(alloc, rom_to_load.?);

    while (motherboard.running) {
        switch (ImGui.process_events()) {
            .none => {},
            .unpause => motherboard.unpause(),
            .pause_type => {
                switch (motherboard.tick_type) {
                    .none => motherboard.tick_type = .instr,
                    .instr => motherboard.tick_type = .clock,
                    .clock => motherboard.tick_type = .phase,
                    .phase => motherboard.tick_type = .none,
                }

                const notify_text = try std.mem.concat(alloc, u8, &.{ "Tick type set to: ", std.enums.tagName(TickType, motherboard.tick_type).? });
                try SDL.notify(alloc, notify_text);
            },
        }
        try motherboard.tick(alloc);

        const temp = rom_to_load.?;

        for (render_states.items) |*state| {
            try SDL.back_render(state);
            if (try ImGui.render(alloc, state, &rom_to_load)) |new_state| {
                try render_states.append(alloc, new_state);
            }
            try motherboard.render(alloc, state);
            try SDL.render(alloc, state);
        }

        if (rom_to_load) |rom| {
            if (!std.mem.eql(u8, temp, rom)) {
                motherboard.running = false;
            }
        } else {
            motherboard.running = false;
            app_state = .Idle;
        }

        // if (motherboard.cpu.addr == 0xC72A) {
        //     motherboard.pause();
        // } else
        switch (motherboard.tick_type) {
            .none => {},
            .instr => if (motherboard.cpu.timing == 2 and motherboard.cpu.phi == 0) motherboard.pause(),
            .clock => if (motherboard.cpu.phi == 0) motherboard.pause(),
            .phase => motherboard.pause(),
        }
    }
}

fn run(alloc: std.mem.Allocator) !void {
    switch (app_state) {
        .Idle => try run_idle(alloc),
        .Running => try run_running(alloc),
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    render_states = try std.ArrayList(RenderState).initCapacity(allocator, 4);

    try render_states.append(allocator, try SDL.init(allocator));
    defer SDL.deinit(allocator, &render_states.items[0]);

    ImGui.init(allocator, &render_states.items[0]);
    defer ImGui.deinit();

    motherboard = try Motherboard.new(&render_states.items[0], call_instruction);
    defer if (motherboard.init) motherboard.deinit(allocator);

    if (try process_args(allocator)) |filename| {
        app_state = .Running;
        rom_to_load = filename;
    }

    while (true) {
        try run(allocator);
    }
}
