const std = @import("std");
const zsdl = @import("zsdl2");
const zgui = @import("zgui");
const nfd = @import("nfd");

const SDL = @import("sdl.zig");

const RenderState = @import("../global.zig").RenderState;
const ProcessResult = @import("../global.zig").ProcessResult;
const WINDOW_WIDTH = @import("../global.zig").WINDOW_WIDTH;
const WINDOW_HEIGHT = @import("../global.zig").WINDOW_HEIGHT;

pub fn init(alloc: std.mem.Allocator, render_state: *RenderState) void {
    zgui.init(alloc);

    _ = zgui.io.addFontFromFile("/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf", 16.0);

    zgui.backend.init(render_state.window, render_state.renderer);
}

pub fn deinit() void {
    zgui.backend.deinit();
    zgui.deinit();
}

pub fn process_events() ProcessResult {
    var e: zsdl.Event = undefined;
    var ret: ProcessResult = .none;

    while (zsdl.pollEvent(&e)) {
        _ = zgui.backend.processEvent(&e);

        const temp = SDL.process_event(&e);
        if (temp != .none) ret = temp;
    }

    return ret;
}

pub fn render(render_state: *RenderState, filename: *?[:0]const u8) !void {
    zgui.backend.newFrame(WINDOW_WIDTH, WINDOW_HEIGHT);

    if (zgui.beginMainMenuBar()) {
        defer zgui.endMainMenuBar();

        if (zgui.beginMenu("File", true)) {
            defer zgui.endMenu();

            if (zgui.menuItem("Open", .{ .shortcut = "Ctrl+O" })) {
                filename.* = try nfd.openFileDialog("nes", ".");
            }
        }
    }

    zgui.render();
    zgui.backend.draw(render_state.renderer);
}
