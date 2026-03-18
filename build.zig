const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "NeedNES",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{},
            .link_libc = true,
        }),
    });

    exe.root_module.linkSystemLibrary("sdl2", .{});
    exe.root_module.linkSystemLibrary("sdl2_ttf", .{});
    // exe.root_module.linkSystemLibrary("GL", .{});

    const zsdl = b.dependency("zsdl", .{});
    exe.root_module.addImport("zsdl2", zsdl.module("zsdl2"));
    exe.root_module.addImport("zsdl2_ttf", zsdl.module("zsdl2_ttf"));

    const zgui = b.dependency("zgui", .{ .shared = false, .with_implot = true, .backend = .sdl2_renderer });
    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.root_module.linkLibrary(zgui.artifact("imgui"));

    const nfd = b.dependency("nfd", .{});
    exe.root_module.addImport("nfd", nfd.module("nfd"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
