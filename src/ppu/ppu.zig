const std = @import("std");
const zsdl = @import("zsdl2");

const ReadWrite = @import("../global.zig").ReadWrite;
const RenderState = @import("../global.zig").RenderState;
const get_bit = @import("../global.zig").get_bit;
const get_bits = @import("../global.zig").get_bits;
const WINDOW_WIDTH = @import("../global.zig").WINDOW_WIDTH;
const WINDOW_HEIGHT = @import("../global.zig").WINDOW_HEIGHT;

// vblank flag is 0x2000 bit 7

fn ShiftRegister(comptime T: type) type {
    const sr_struct = struct {
        hi: T,
        lo: T,
        const Self = @This();

        pub fn shift(self: *Self, in: u2) void {
            self.lo, _ = @shlWithOverflow(self.lo, 1);
            self.hi, _ = @shlWithOverflow(self.hi, 1);

            self.lo += @as(T, in & 1);
            self.hi += @as(T, in & 2) >> 1;
        }

        pub fn read_bit(self: *Self, bit: u16) u2 {
            const shift_amt = @as(T, bit - 1);
            const outl: u2 = @intCast((self.lo & (1 << shift_amt)) >> shift_amt);
            const outh: u2 = @intCast((self.hi & (1 << shift_amt)) >> shift_amt);

            return outl | (outh << 1);
        }
    };

    return sr_struct;
}

const colors = [0x40 * 0x8]zsdl.Color{.{ .r = 0, .b = 0, .g = 0, .a = 0 }} ** 0x200;

const SetColorsAtError = error{NotColorFile};
pub fn set_colors_at(filename: [:0]const u8) !void {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const size = (try file.stat()).size;

    if (size != 0x600) {
        std.debug.print("UH OH! {s} isn't a color file!", .{filename});
        return SetColorsAtError.NotColorFile;
    }

    for (0..0x200) |i| {
        var color = [3]u8{0} ** 3;
        file.read(&color);

        color[i] = zsdl.Color{ .r = color[0], .g = color[1], .b = color[2], .a = 0xFF };
    }
}

const DOT_COUNT = 256;
const SCANLINE_COUNT = 240;
const TRUE_DOT_COUNT = 340;
const TRUE_SCANLINE_COUNT = 261;

pub const PPU = struct {
    chip_enable: u1,
    rw: ReadWrite,
    cpu_data: u8,
    cpu_addr: u3,

    ppu_data: u8,
    ppu_addr: u15,

    ppuctrl: u8,
    ppumask: u8,
    ppustatus: u8,
    oamaddr: u8,
    oamdata: u8,
    ppudata: u8,
    oamdma: u8,

    v: u15,
    t: u15,
    x: u3,
    w: u1,

    w_latch: u8,

    dot: u9,
    scanline: u9,

    pattern_data: ShiftRegister(u16),
    attrib_data: ShiftRegister(u8),
    attrib_latch: u2,

    palette_ram: [0x20]u8,

    screen_output: [SCANLINE_COUNT * DOT_COUNT]zsdl.Color,

    pub fn reset(self: *PPU) void {
        self.ppuctrl = 0;
        self.ppumask = 0;

        self.x = 0;
        self.w = 0;

        self.w_latch = 0;
        self.ppudata = 0;
    }

    pub fn power(self: *PPU) void {
        self.ppustatus |= 0b10100000;

        self.t = 0;
    }

    // simple functions
    fn get_emphasis(self: *PPU) u3 {
        return get_bits(self.ppumask, 5, 7);
    }

    // rendering
    fn scale_screen(self: *PPU, scale: u8, output: *[]zsdl.Color) !void {
        for (0..SCANLINE_COUNT) |y| {
            for (0..DOT_COUNT) |x| {
                const color = self.screen_output[y * DOT_COUNT + x];
                const sx = x * scale;
                const sy = y * scale;
                const sw = DOT_COUNT * @as(u16, scale);
                output.*[sy * sw + sx] = color;
                output.*[sy * sw + sx + 1] = color;
                output.*[(sy + 1) * sw + sx] = color;
                output.*[(sy + 1) * sw + sx + 1] = color;
            }
        }
    }

    pub fn render(self: *PPU, alloc: std.mem.Allocator, render_state: *RenderState) !void {
        if (render_state.textures.items.len == 0) {
            const main_texture = try zsdl.createTexture(render_state.renderer, .abgr8888, .streaming, WINDOW_WIDTH, WINDOW_HEIGHT);
            try render_state.textures.append(alloc, main_texture);
        }

        const main_texture = render_state.textures.getLast(); // if we make any other textures, we're fucked
        var main_rect = zsdl.Rect{
            .x = 0,
            .y = 0,
            .w = WINDOW_WIDTH,
            .h = WINDOW_HEIGHT,
        };

        // var scaled_output = try alloc.alloc(zsdl.Color, (DOT_COUNT * 2) * (SCANLINE_COUNT * 2));
        // defer alloc.destroy(scaled_output);

        // try self.scale_screen(2, &scaled_output);

        try zsdl.updateTexture(main_texture, &main_rect, @ptrCast(&self.screen_output[0]), WINDOW_WIDTH * @sizeOf(zsdl.Color));
    }

    // emulation

    fn shift_tile_data(self: *PPU) void {
        self.pattern_data.shift(2);
        self.attrib_data.shift(self.attrib_latch);
    }

    fn mux_output(self: *PPU) void {
        const pattern_x: u4 = self.x + 8;

        const pattern_color: u4 = self.pattern_data.read_bit(pattern_x);
        const attrib_color: u4 = self.attrib_data.read_bit(self.x);

        const color_index = pattern_color | (attrib_color << 2);
        const nes_color = self.palette_ram[color_index];

        const color = colors[nes_color * self.get_emphasis()];

        self.screen_output[(self.scanline * DOT_COUNT) + self.dot] = color;
    }

    fn output_curr_pixel(self: *PPU) void {
        self.shift_tile_data();
        self.mux_output();
    }

    fn state_read(self: *PPU) void {
        _ = self;
    }

    fn calculate_next_sliver(self: *PPU) void {
        _ = self;
    }

    pub fn tick(self: *PPU) void {
        self.output_curr_pixel();

        if (self.dot % 2 == 0) {
            self.state_read();
        } else {
            self.calculate_next_sliver();
        }
    }

    pub fn new() PPU {
        return std.mem.zeroes(PPU);
    }
};
