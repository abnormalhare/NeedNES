const std = @import("std");

const zsdl = @import("zsdl2");

const CPU = @import("cpu/cpu.zig").CPU;
const RAM = @import("ram/ram.zig").RAM;

const Mapper = @import("mapper/mapper.zig").Mapper;
const NROM = @import("mapper/000_nrom.zig").NROM;

const RenderState = @import("global.zig").RenderState;
const TickType = @import("global.zig").TickType;
const interpret_nes_header = @import("global.zig").interpret_nes_header;
const WHITE = @import("global.zig").WHITE;

const RomLoadError = error{NotNESROM};

pub const Motherboard = struct {
    running: bool,
    paused: bool,
    init: bool,

    power_btn: u1,
    reset_btn: u1,

    tick_type: TickType,

    cpu: CPU,
    ram: RAM,
    mapper: Mapper,

    pub fn power(self: *Motherboard) void {
        self.running = true;
        self.cpu.power();
    }

    pub fn pause(self: *Motherboard) void {
        self.paused = true;
    }

    pub fn unpause(self: *Motherboard) void {
        self.paused = false;
    }

    pub fn subtick_update(self: *Motherboard) void {
        if (self.cpu.rw == .read) {
            _ = self.mapper.read_cpu(0, self.cpu.addr);
        } else {
            _ = self.mapper.write_cpu(self.cpu.addr, self.cpu.data);
        }

        self.ram.rw = self.cpu.rw;
        self.ram.addr = @truncate(self.cpu.addr);
        self.ram.chip_enable = @intFromBool((self.cpu.addr >> 12) < 4); // technically !(A12 | A13 | A14 | A15)
        if (self.cpu.rw == .write) {
            self.ram.latch = self.cpu.data;
        }
    }

    pub fn tick_update(self: *Motherboard) void {
        self.ram.phi = self.cpu.phi;

        if (self.cpu.rw == .read and self.cpu.phi == 1) {
            var already_read: bool = false;

            if (self.mapper.read_cpu(1, self.cpu.addr)) |data| {
                self.cpu.data = data;
                already_read = true;
            }

            if (self.ram.chip_enable == 1) {
                if (already_read) {
                    std.debug.print("OH NO! Unhandled double data.", .{});
                }
                self.cpu.data = self.ram.latch;
                already_read = true;
            }
        }
    }

    pub fn tick(self: *Motherboard) void {
        if (self.paused or !self.running) return;

        self.cpu.tick();
        self.subtick_update();
        self.ram.tick();

        self.tick_update();
    }

    pub fn generate_debug_text(self: *Motherboard, alloc: std.mem.Allocator) ![:0]const u8 {
        var list = try std.ArrayList(u8).initCapacity(alloc, 0x2000);
        defer list.deinit(alloc);

        const writer = list.writer(alloc);

        try writer.print("IR: {X:0>2} A: {X:0>2} X: {X:0>2} Y: {X:0>2}  P: {X:0>2}  S:{X:0>2}\n", .{
            self.cpu.ir,
            self.cpu.a,
            self.cpu.x,
            self.cpu.y,
            self.cpu.p.to_num(),
            self.cpu.s,
        });
        try writer.print("ADDR: {X:0>4}  PC: {X:0>4}  DATA: {X:0>2}\n", .{ self.cpu.addr, self.cpu.pc, self.cpu.data });
        try writer.print("ADL: {X:0>2}  ADH: {X:0>2}\n", .{ self.cpu.adl, self.cpu.adh });
        try writer.print("TIME: {X:0>1}  PHI: {X:0>1}\n\n", .{ self.cpu.timing, self.cpu.phi });
        try writer.print("RAM: {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2}\n", .{ self.ram.data[0], self.ram.data[1], self.ram.data[2], self.ram.data[3], self.ram.data[4], self.ram.data[5], self.ram.data[6], self.ram.data[7] });
        try writer.print("STACK: {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2} {X:0>2}\n", .{ self.ram.data[0x1F8], self.ram.data[0x1F9], self.ram.data[0x1FA], self.ram.data[0x1FB], self.ram.data[0x1FC], self.ram.data[0x1FD], self.ram.data[0x1FE], self.ram.data[0x1FF] });

        return list.toOwnedSliceSentinel(alloc, 0);
    }

    pub fn render(self: *Motherboard, alloc: std.mem.Allocator, render_state: *RenderState) !void {
        const debug_text = try self.generate_debug_text(alloc);
        defer alloc.free(debug_text);

        const text_surface: *zsdl.Surface = try render_state.debug_font.renderTextBlendedWrapped(debug_text, WHITE, 300);
        const text_texture: *zsdl.Texture = try render_state.renderer.createTextureFromSurface(text_surface);

        const text_rect: zsdl.Rect = .{
            .x = 300 - @divFloor(text_surface.w, 2),
            .y = 100,
            .w = text_surface.w,
            .h = text_surface.h,
        };

        try render_state.renderer.copy(text_texture, null, &text_rect);

        text_texture.destroy();
        text_surface.free();
    }

    pub fn load_rom(self: *Motherboard, alloc: std.mem.Allocator, filename: [:0]const u8) !void {
        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        const size = (try file.stat()).size;

        var verify: [4]u8 = [_]u8{0} ** 4;
        _ = try file.read(&verify);
        if (!std.mem.eql(u8, &verify, "NES\x1A")) return RomLoadError.NotNESROM;

        var header: [0xC]u8 = [_]u8{0} ** 0xC;
        _ = try file.read(&header);

        const info = interpret_nes_header(&header);

        var rom = try alloc.alloc(u8, size - 0x10);
        defer alloc.free(rom);
        _ = try file.read(rom);

        self.mapper = try Mapper.new(alloc, NROM, &rom, info);

        self.init = true;
    }

    pub fn new(render_state: *RenderState, call_instruction: *const fn (u8, *CPU) void) !Motherboard {
        return .{
            .running = false,
            .paused = false,
            .init = false,

            .power_btn = 0,
            .reset_btn = 0,
            .tick_type = .instr,

            .cpu = CPU.new(render_state, call_instruction),
            .ram = RAM.new(),
            .mapper = undefined,
        };
    }

    pub fn deinit(self: *Motherboard, alloc: std.mem.Allocator) void {
        self.mapper.deinit(alloc);
    }
};
