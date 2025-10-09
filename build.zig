const std = @import("std");

const ModuleImport = std.Build.Module.Import;

fn createModuleWithImports(
    b: *std.Build,
    root_rel_path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const ModuleImport,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path(root_rel_path),
        .target = target,
        .optimize = optimize,
        .imports = imports,
    });
}

fn addExecutableWithImports(
    b: *std.Build,
    name: []const u8,
    root_rel_path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const ModuleImport,
) *std.Build.Step.Compile {
    const module = createModuleWithImports(b, root_rel_path, target, optimize, imports);
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = module,
    });
    b.installArtifact(exe);
    return exe;
}

fn addTestWithImports(
    b: *std.Build,
    root_rel_path: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const ModuleImport,
) *std.Build.Step.Compile {
    const module = createModuleWithImports(b, root_rel_path, target, optimize, imports);
    return b.addTest(.{
        .root_module = module,
    });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core module exposed to dependents.
    const ohlcv_module = b.addModule("ohlcv", .{
        .root_source_file = b.path("lib/ohlcv.zig"),
        .target = target,
        .optimize = optimize,
    });
    const ohlcv_imports_storage = [_]ModuleImport{
        .{ .name = "ohlcv", .module = ohlcv_module },
    };
    const ohlcv_imports = ohlcv_imports_storage[0..];

    // Optional static library for direct linking.
    const lib = b.addLibrary(.{
        .name = "ohlcv",
        .root_module = ohlcv_module,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // Unit tests (compile + run).
    const test_helpers_module = createModuleWithImports(
        b,
        "test/test_helpers.zig",
        target,
        optimize,
        ohlcv_imports,
    );
    const test_imports_storage = [_]ModuleImport{
        .{ .name = "ohlcv", .module = ohlcv_module },
        .{ .name = "test_helpers", .module = test_helpers_module },
    };
    const tests = addTestWithImports(
        b,
        "test/test_all.zig",
        target,
        optimize,
        test_imports_storage[0..],
    );
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run unit tests").dependOn(&run_tests.step);

    // Demo executable + `zig build run`.
    const demo = addExecutableWithImports(
        b,
        "demo",
        "demo.zig",
        target,
        optimize,
        ohlcv_imports,
    );
    const run_demo = b.addRunArtifact(demo);
    if (b.args) |args| run_demo.addArgs(args);
    b.step("run", "Build and run demo").dependOn(&run_demo.step);

    // Benchmarks and profiling helpers.
    const bench_release = std.builtin.OptimizeMode.ReleaseFast;

    const benchmark = addExecutableWithImports(
        b,
        "benchmark",
        "benchmark/simple_benchmark.zig",
        target,
        bench_release,
        ohlcv_imports,
    );
    const benchmark_run = b.addRunArtifact(benchmark);
    b.step("benchmark", "Run basic benchmark").dependOn(&benchmark_run.step);

    const benchmark_streaming = addExecutableWithImports(
        b,
        "benchmark-streaming",
        "benchmark/streaming_benchmark.zig",
        target,
        bench_release,
        ohlcv_imports,
    );
    const benchmark_streaming_run = b.addRunArtifact(benchmark_streaming);
    b.step("benchmark-streaming", "Run streaming benchmark").dependOn(&benchmark_streaming_run.step);

    const benchmark_performance = addExecutableWithImports(
        b,
        "benchmark-performance",
        "benchmark/performance_benchmark.zig",
        target,
        bench_release,
        ohlcv_imports,
    );
    const benchmark_performance_run = b.addRunArtifact(benchmark_performance);
    b.step("benchmark-performance", "Run comprehensive performance benchmark").dependOn(&benchmark_performance_run.step);

    const memory_profiler = addExecutableWithImports(
        b,
        "memory-profiler",
        "benchmark/simple_memory_profiler.zig",
        target,
        std.builtin.OptimizeMode.Debug,
        ohlcv_imports,
    );
    const memory_profile_run = b.addRunArtifact(memory_profiler);
    b.step("profile-memory", "Run memory profiler").dependOn(&memory_profile_run.step);
}
