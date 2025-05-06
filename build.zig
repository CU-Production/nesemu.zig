const std = @import("std");
const shdc = @import("shdc");

pub fn build(b: *std.Build) !void {
    // shdc shader compiler
    const shader_name = "triangle";
    const shd_step = try buildShader(b, shader_name);

    // build exe
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "testsokolzig",
        .root_module = exe_mod,
    });
    exe.addCSourceFile(.{
        .file = b.path("lib/agnes/src/agnes.c"),
        .flags = &[_][]const u8{
            "-std=c99",
        },
    });
    exe.addIncludePath(b.path("lib/agnes/src"));

    exe.root_module.addImport("sokol", dep_sokol.module("sokol"));

    exe.step.dependOn(&shd_step.step);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn buildShader(b: *std.Build, shader_name: []const u8) !*std.Build.Step.Run {
    const shaders_dir = "src/shaders/";
    const input_path = b.fmt("{s}{s}.glsl", .{ shaders_dir, shader_name });
    const output_path = b.fmt("{s}{s}.glsl.zig", .{ shaders_dir, shader_name });
    return shdc.compile(b, .{
        .dep_shdc = b.dependency("shdc", .{}),
        .input = b.path(input_path),
        .output = b.path(output_path),
        .slang = .{
            .glsl430 = false,
            .glsl410 = true,
            .glsl310es = false,
            .glsl300es = true,
            .metal_macos = true,
            .hlsl5 = true,
            .wgsl = true,
        },
        .reflection = true,
    });
}
