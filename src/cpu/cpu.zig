const std = @import("std");
const zsdl = @import("zsdl2");
const zsdl_ttf = @import("zsdl2_ttf");

const RenderState = @import("../global.zig").RenderState;
const ReadWrite = @import("../global.zig").ReadWrite;
const get_bit = @import("../global.zig").get_bit;

const Instructions = @import("instructions.zig");

const Flags = packed struct {
    c: u1,
    z: u1,
    i: u1,
    d: u1,
    b: u1,
    q: u1,
    v: u1,
    n: u1,

    pub fn to_num(self: *Flags) u8 {
        var val: u8 = @intCast(self.c);
        val += @as(u8, self.z) << 1;
        val += @as(u8, self.i) << 2;
        val += @as(u8, self.d) << 3;
        val += @as(u8, self.b) << 4;
        val += @as(u8, self.q) << 5;
        val += @as(u8, self.v) << 6;
        val += @as(u8, self.n) << 7;

        return val;
    }

    pub fn set_num(self: *Flags, num: u8) void {
        self.c = get_bit(num, 0);
        self.z = get_bit(num, 1);
        self.i = get_bit(num, 2);
        self.d = get_bit(num, 3);
        self.v = get_bit(num, 6);
        self.n = get_bit(num, 7);
    }

    fn new() Flags {
        return .{
            .c = 0,
            .z = 0,
            .i = 0,
            .d = 0,
            .b = 0,
            .q = 1,
            .v = 0,
            .n = 0,
        };
    }
};

const Event = struct {
    timing: u3,
    phase: u1,
    callback: *const fn (*CPU) void,
    args: []u32,
};

fn empty_func() void {}

pub const CPU = struct {
    call_instruction: *const fn (u8, *CPU) void,
    event: [4]?Event,

    render_state: *RenderState,

    timing: u3,
    phi: u1,
    halt: u1,

    ir: u8,

    a: u8,
    x: u8,
    y: u8,

    s: u8,
    p: Flags,
    pc: u16,
    addr: u16,

    adl: u8,
    adh: u8,
    add: u8,

    data: u8,
    rw: ReadWrite,

    // initialization

    fn reset(self: *CPU) void {
        self.s, _ = @subWithOverflow(self.s, 3);
        self.p.i = 1;

        // self.pc = 0xFFFC;
        // self.ir = 0x6C;
        self.timing = 1;
        self.pc = 0xC000;
    }

    pub fn power(self: *CPU) void {
        self.reset();

        self.a = 0;
        self.x = 0;
        self.y = 0;

        self.s = 0xFD;

        self.p.c = 0;
        self.p.z = 0;
        self.p.d = 0;
        self.p.v = 0;
        self.p.n = 0;
    }

    // handling

    pub fn add_event(self: *CPU, timing: u3, phase: u1, callback: *const fn (*CPU) void, args: []u32) void {
        for (&self.event) |*event| {
            if (event.*) |e| {
                _ = e;
                continue;
            }

            event.* = .{
                .timing = timing,
                .phase = phase,
                .callback = callback,
                .args = args,
            };
        } else {
            std.debug.print("Whoops! We ran out of events. guess we're gonna die.\n", .{});
            std.process.exit(0);
        }
    }

    // read/write
    pub fn read(self: *CPU) void {
        self.rw = .read;
    }

    pub fn read_stack(self: *CPU) void {
        self.addr = @as(u16, self.s) + 0x100;
        self.read();
    }

    pub fn read_pc(self: *CPU) void {
        self.addr = self.pc;
        self.pc += 1;
        self.read();
    }

    pub fn read_ir(self: *CPU) void {
        if (self.phi == 0) {
            self.read_pc();
        } else {
            self.ir = self.data;
        }
    }

    pub fn write(self: *CPU) void {
        self.rw = .write;
    }

    pub fn write_stack(self: *CPU) void {
        self.write();
        self.s -= 1;
    }

    // emulation

    fn to_next_state(self: *CPU) void {
        self.phi, const temp = @addWithOverflow(self.phi, 1);
        self.timing, _ = @addWithOverflow(self.timing, temp);
    }

    pub fn tick(self: *CPU) void {
        if (self.halt == 1) return;

        switch (self.timing) {
            1 => self.read_ir(),
            else => self.call_instruction(self.ir, self),
        }
        self.to_next_state();
    }

    pub fn new(render_state: *RenderState, call_instruction: *const fn (u8, *CPU) void) CPU {
        const self: CPU = .{
            .call_instruction = call_instruction,
            .render_state = render_state,
            .event = [_]?Event{null} ** 4,

            .timing = 0,
            .phi = 0,
            .halt = 0,

            .ir = 0,

            .a = 0,
            .x = 0,
            .y = 0,

            .s = 0,
            .p = Flags.new(),
            .pc = 0,
            .addr = 0,

            .adl = 0,
            .adh = 0,
            .add = 0,

            .data = 0,
            .rw = .write,
        };

        return self;
    }
};
