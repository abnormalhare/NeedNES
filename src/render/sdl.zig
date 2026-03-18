const std = @import("std");
const zsdl = @import("zsdl2");
const zsdl_ttf = @import("zsdl2_ttf");

const RenderState = @import("../global.zig").RenderState;
const ProcessResult = @import("../global.zig").ProcessResult;
const WINDOW_WIDTH = @import("../global.zig").WINDOW_WIDTH;
const WINDOW_HEIGHT = @import("../global.zig").WINDOW_HEIGHT;
const BLACK = @import("../global.zig").BLACK;
const WHITE = @import("../global.zig").WHITE;

pub fn init(alloc: std.mem.Allocator) !RenderState {
    try zsdl.init(.everything);
    errdefer zsdl.quit();

    const window = try zsdl.createWindow("NeedNES", zsdl.Window.pos_undefined, zsdl.Window.pos_undefined, WINDOW_WIDTH, WINDOW_HEIGHT, .{ .shown = true, .opengl = true });
    errdefer window.destroy();

    const renderer = try zsdl.createRenderer(window, null, .{});
    errdefer renderer.destroy();

    try zsdl_ttf.init();
    errdefer zsdl_ttf.quit();

    const debug_font: *zsdl_ttf.Font = try .open("assets/Ubuntu-C.ttf", 16);
    errdefer debug_font.close();

    const ret: RenderState = .{
        .window = window,
        .renderer = renderer,
        .debug_font = debug_font,

        .surfaces = try .initCapacity(alloc, 1),
    };
    errdefer ret.surfaces.clearAndFree(alloc);

    return ret;
}

pub fn deinit(alloc: std.mem.Allocator, render_state: *RenderState) void {
    render_state.debug_font.close();
    render_state.renderer.destroy();
    render_state.surfaces.clearAndFree(alloc);
    render_state.window.destroy();

    zsdl.quit();
}

pub fn process_event(e: *zsdl.Event) ProcessResult {
    switch (e.type) {
        .quit => std.process.exit(0),
        .keydown => {
            if (e.key.keysym.scancode == .escape) {
                std.process.exit(0);
            }
            if (e.key.keysym.scancode == .@"return") {
                return ProcessResult.unpause;
            }
            if (e.key.keysym.scancode == .p) {
                return ProcessResult.pause_type;
            }
        },
        else => {},
    }

    return ProcessResult.none;
}

pub fn back_render(render_state: *RenderState) !void {
    try render_state.renderer.setDrawColor(BLACK);
    try render_state.renderer.clear();
}

var notify_timer: f64 = 0;
var notify_text: ?[:0]const u8 = null;
var last_time: f64 = 0;
var curr_time: f64 = 0;

pub fn render(alloc: std.mem.Allocator, render_state: *RenderState) !void {
    if (notify_text) |text| {
        if (notify_timer <= 0) {
            alloc.free(notify_text.?);
            notify_text = null;
            return;
        }

        var color: zsdl.Color = WHITE;

        if (notify_timer <= 0.25) {
            var new_color: i32 = @intFromFloat(notify_timer * (255 * 4));
            if (new_color < 0) new_color = 0;

            const new_color_2: u32 = @intCast(new_color);

            color.r = @truncate(new_color_2);
            color.g = @truncate(new_color_2);
            color.b = @truncate(new_color_2);
        }

        const text_surface: *zsdl.Surface = try render_state.debug_font.renderTextBlendedWrapped(text, color, 300);
        const text_texture: *zsdl.Texture = try render_state.renderer.createTextureFromSurface(text_surface);

        const text_rect: zsdl.Rect = .{
            .x = 300 - @divFloor(text_surface.w, 2),
            .y = 400,
            .w = text_surface.w,
            .h = text_surface.h,
        };

        try render_state.renderer.copy(text_texture, null, &text_rect);

        text_texture.destroy();
        text_surface.free();

        curr_time = @as(f64, @floatFromInt(std.time.milliTimestamp())) / 1000.0;
        notify_timer -= curr_time - last_time;
        last_time = curr_time;
    }

    render_state.renderer.present();
}

pub fn notify(alloc: std.mem.Allocator, text: []u8) !void {
    if (notify_text != null) {
        alloc.free(notify_text.?);
    }
    notify_timer = 1.5;
    notify_text = try alloc.dupeZ(u8, text);
    last_time = @as(f64, @floatFromInt(std.time.milliTimestamp())) / 1000.0;
}
