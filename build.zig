const std = @import("std");

pub fn build(b: *std.Build) void {
    const lib = b.addModule("ohlcv_lib", .{
        .root_source_file = b.path("src/lib.zig"),
    });

    const exe = b.addExecutable(.{
        .name = "ohlcv",
        .root_source_file = b.path("src/main.zig"),
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    exe.root_module.addImport("ohlcv_lib", lib);
    b.installArtifact(exe);

    // Optional: test step
    const main_tests = b.addTest(.{ .root_source_file = b.path("src/lib.zig") });
    b.default_step.dependOn(&main_tests.step);
}
