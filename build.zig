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

    // Optional: build a static library artifact for consumers who prefer linking
    // (module-based import remains the primary integration method)
    const lib = b.addStaticLibrary(.{
        .name = "ohlcv",
        .root_source_file = b.path("lib/ohlcv.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

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

    // ─── Benchmark executables ───
    const benchmark_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("benchmark/simple_benchmark.zig"),
        .target = target,
        .optimize = .ReleaseFast, // Always use fast optimization for benchmarks
    });
    benchmark_exe.root_module.addImport("ohlcv", mod);
    b.installArtifact(benchmark_exe);

    const benchmark_run = b.addRunArtifact(benchmark_exe);
    b.step("benchmark", "Run performance benchmarks").dependOn(&benchmark_run.step);

    // ─── Advanced benchmark ───
    const adv_benchmark_exe = b.addExecutable(.{
        .name = "benchmark-advanced",
        .root_source_file = b.path("benchmark/benchmark_indicators.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    adv_benchmark_exe.root_module.addImport("ohlcv", mod);
    b.installArtifact(adv_benchmark_exe);

    const adv_benchmark_run = b.addRunArtifact(adv_benchmark_exe);
    b.step("benchmark-advanced", "Run advanced performance benchmarks").dependOn(&adv_benchmark_run.step);

    // ─── Memory profiler ───
    const profiler_exe = b.addExecutable(.{
        .name = "memory-profiler",
        .root_source_file = b.path("benchmark/simple_memory_profiler.zig"),
        .target = target,
        .optimize = .Debug, // Use debug for memory profiling
    });
    profiler_exe.root_module.addImport("ohlcv", mod);
    b.installArtifact(profiler_exe);

    const profiler_run = b.addRunArtifact(profiler_exe);
    b.step("profile-memory", "Run memory profiling").dependOn(&profiler_run.step);
}
