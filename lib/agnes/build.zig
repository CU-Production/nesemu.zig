const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
const LibExeObjStep = std.build.LibExeObjStep;
const CrossTarget = std.zig.CrossTarget;
const Mode = std.builtin.Mode;

// build agnes into a static library
pub fn buildAgnes(b: *Builder, target: CrossTarget, mode: Mode, comptime prefix_path: []const u8) *LibExeObjStep {
    const lib = b.addStaticLibrary("agnes", null);
    lib.setBuildMode(mode);
    lib.setTarget(target);

    lib.linkLibC();
    const agnes_path = prefix_path ++ "src/";
    const csources = [_][]const u8{
        "agnes.c",
    };

    inline for (csources) |csrc| {
        lib.addCSourceFile(agnes_path ++ csrc, &[_][]const u8{""});
    }

    return lib;
}
