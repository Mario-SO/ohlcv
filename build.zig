const std = @import("std");

const has_exe_root_source = @hasField(std.Build.ExecutableOptions, "root_source_file");
const has_test_root_source = @hasField(std.Build.TestOptions, "root_source_file");
const has_add_static_library = @hasDecl(std.Build, "addStaticLibrary");

fn addExecutableWithImports(
    b: *std.Build,
    name: []const u8,
    root_rel_path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import,
) *std.Build.Step.Compile {
    if (has_exe_root_source) {
        const exe = b.addExecutable(.{
            .name = name,
            .root_source_file = b.path(root_rel_path),
            .target = target,
            .optimize = optimize,
        });
        for (imports) |imp| {
            exe.root_module.addImport(imp.name, imp.module);
        }
        return exe;
    } else {
        const module = b.createModule(.{
            .root_source_file = b.path(root_rel_path),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        });
        return b.addExecutable(.{
            .name = name,
            .root_module = module,
        });
    }
}

fn addTestWithImports(
    b: *std.Build,
    root_rel_path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import,
) *std.Build.Step.Compile {
    if (has_test_root_source) {
        const tst = b.addTest(.{
            .root_source_file = b.path(root_rel_path),
            .target = target,
            .optimize = optimize,
        });
        for (imports) |imp| {
            tst.root_module.addImport(imp.name, imp.module);
        }
        return tst;
    } else {
        const module = b.createModule(.{
            .root_source_file = b.path(root_rel_path),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        });
        return b.addTest(.{
            .root_module = module,
        });
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ─── Library module ───
    const mod = b.addModule("ohlcv", .{
        .root_source_file = b.path("lib/ohlcv.zig"),
        .target = target,
        .optimize = optimize,
    });
    const ohlcv_imports = &.{.{ .name = "ohlcv", .module = mod }};

    // Optional static library artifact; support both addStaticLibrary (<=0.14) and addLibrary (>=0.15)
    const lib = if (has_add_static_library) blk: {
        break :blk b.addStaticLibrary(.{
            .name = "ohlcv",
            .root_source_file = b.path("lib/ohlcv.zig"),
            .target = target,
            .optimize = optimize,
        });
    } else blk: {
        break :blk b.addLibrary(.{
            .name = "ohlcv",
            .root_module = mod,
            .linkage = .static,
        });
    };
    b.installArtifact(lib);

    // ─── Unit‑tests (compile + run) ───
    const test_helpers_module = b.createModule(.{
        .root_source_file = b.path("test/test_helpers.zig"),
        .imports = ohlcv_imports,
        .target = target,
        .optimize = optimize,
    });
    const test_imports = &.{
        .{ .name = "ohlcv", .module = mod },
        .{ .name = "test_helpers", .module = test_helpers_module },
    };
    const tst_obj = addTestWithImports(
        b,
        "test/test_all.zig",
        target,
        optimize,
        test_imports,
    );
    const tst_run = b.addRunArtifact(tst_obj);
    b.step("test", "Run unit tests").dependOn(&tst_run.step);

    // ─── Demo executable ───
    const exe = addExecutableWithImports(
        b,
        "demo",
        "demo.zig",
        target,
        optimize,
        ohlcv_imports,
    );
    b.installArtifact(exe);

    // ─── "zig build run" convenience step ───
    const run_cmd = b.addRunArtifact(exe);
    // Pipe any args from the command line: `zig build run -- arg1 arg2`
    if (b.args) |user_args| run_cmd.addArgs(user_args);
    b.step("run", "Build and run demo").dependOn(&run_cmd.step);

    // ─── Benchmark executables ───
    const benchmark_exe = addExecutableWithImports(
        b,
        "benchmark",
        "benchmark/simple_benchmark.zig",
        target,
        .ReleaseFast, // Always use fast optimization for benchmarks
        ohlcv_imports,
    );
    b.installArtifact(benchmark_exe);

    const benchmark_run = b.addRunArtifact(benchmark_exe);
    b.step("benchmark", "Run performance benchmarks").dependOn(&benchmark_run.step);

    // ─── Memory profiler ───
    const profiler_exe = addExecutableWithImports(
        b,
        "memory-profiler",
        "benchmark/simple_memory_profiler.zig",
        target,
        .Debug, // Use debug for memory profiling
        ohlcv_imports,
    );
    b.installArtifact(profiler_exe);

    const profiler_run = b.addRunArtifact(profiler_exe);
    b.step("profile-memory", "Run memory profiling").dependOn(&profiler_run.step);

    // ─── Streaming benchmark ───
    const streaming_benchmark_exe = addExecutableWithImports(
        b,
        "benchmark-streaming",
        "benchmark/streaming_benchmark.zig",
        target,
        .ReleaseFast,
        ohlcv_imports,
    );
    b.installArtifact(streaming_benchmark_exe);

    const streaming_benchmark_run = b.addRunArtifact(streaming_benchmark_exe);
    b.step("benchmark-streaming", "Run streaming vs non-streaming benchmark").dependOn(&streaming_benchmark_run.step);

    // ─── Performance benchmark ───
    const perf_benchmark_exe = addExecutableWithImports(
        b,
        "benchmark-performance",
        "benchmark/performance_benchmark.zig",
        target,
        .ReleaseFast,
        ohlcv_imports,
    );
    b.installArtifact(perf_benchmark_exe);

    const perf_benchmark_run = b.addRunArtifact(perf_benchmark_exe);
    b.step("benchmark-performance", "Run comprehensive performance benchmark").dependOn(&perf_benchmark_run.step);
}
