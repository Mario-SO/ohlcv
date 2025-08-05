const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ─── Library module ───
    const mod = b.addModule("ohlcv", .{
        .root_source_file = b.path("lib/ohlcv.zig"),
        .target = target,
        .optimize = optimize,
    });

    // ─── Unit‑tests (compile + run) ───
    const tst_obj = b.addTest(.{
        .root_source_file = b.path("test/test_all.zig"),
        .target = target,
        .optimize = optimize,
    });
    tst_obj.root_module.addImport("ohlcv", mod);
    tst_obj.root_module.addImport("test_helpers", b.createModule(.{
        .root_source_file = b.path("test/test_helpers.zig"),
        .imports = &.{
            .{ .name = "ohlcv", .module = mod },
        },
    }));
    const tst_run = b.addRunArtifact(tst_obj);
    b.step("test", "Run unit tests").dependOn(&tst_run.step);

    // ─── Demo executable ───
    const exe = b.addExecutable(.{
        .name = "demo",
        .root_source_file = b.path("demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ohlcv", mod);
    b.installArtifact(exe);

    // ─── "zig build run" convenience step ───
    const run_cmd = b.addRunArtifact(exe);
    // Pipe any args from the command line: `zig build run -- arg1 arg2`
    if (b.args) |user_args| run_cmd.addArgs(user_args);
    b.step("run", "Build and run demo").dependOn(&run_cmd.step);
}
