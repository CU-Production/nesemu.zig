const std = @import("std");
const sokol = @import("lib/sokol-zig/build.zig");
const agnes = @import("lib/agnes/build.zig");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const sokol_build = sokol.buildSokol(b, target, mode, .{}, "lib/sokol-zig/");
    const agnes_build = agnes.buildAgnes(b, target, mode, "lib/agnes/");

    const exe = b.addExecutable("nesemu.zig", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackagePath("sokol", "lib/sokol-zig/src/sokol/sokol.zig");
    exe.linkLibrary(sokol_build);
    exe.addIncludePath("lib/agnes/src");
    exe.linkLibrary(agnes_build);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
