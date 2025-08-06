// ╔════════════════════════════════════ Indicator Benchmarks ════════════════════════════════════╗

const std = @import("std");
const ohlcv = @import("ohlcv");
const Allocator = std.mem.Allocator;

const BenchmarkResult = struct {
    name: []const u8,
    duration_ns: u64,
    operations: u32,
    ns_per_op: f64,
    memory_used: usize,
};

const BenchmarkSuite = struct {
    allocator: Allocator,
    results: std.ArrayList(BenchmarkResult),

    pub fn init(allocator: Allocator) BenchmarkSuite {
        return .{
            .allocator = allocator,
            .results = std.ArrayList(BenchmarkResult).init(allocator),
        };
    }

    pub fn deinit(self: *BenchmarkSuite) void {
        self.results.deinit();
    }

    pub fn addResult(self: *BenchmarkSuite, result: BenchmarkResult) !void {
        try self.results.append(result);
    }

    pub fn printResults(self: *BenchmarkSuite) void {
        std.debug.print("\n{s}\n", .{"═" ** 80});
        std.debug.print("OHLCV Library Performance Benchmarks\n", .{});
        std.debug.print("{s}\n", .{"═" ** 80});
        std.debug.print("{s:<40} {s:>15} {s:>12} {s:>10}\n", .{ "Test", "Duration (ms)", "Ops", "ns/op" });
        std.debug.print("{s}\n", .{"─" ** 80});

        for (self.results.items) |result| {
            const duration_ms = @as(f64, @floatFromInt(result.duration_ns)) / 1_000_000.0;
            std.debug.print("{s:<40} {d:>15.3} {d:>12} {d:>10.1}\n", .{
                result.name,
                duration_ms,
                result.operations,
                result.ns_per_op,
            });
        }
        std.debug.print("{s}\n\n", .{"═" ** 80});
    }
};

fn generateTestData(allocator: Allocator, size: usize) ![]ohlcv.OhlcvRow {
    const data = try allocator.alloc(ohlcv.OhlcvRow, size);
    
    var rng = std.Random.DefaultPrng.init(42); // Fixed seed for reproducibility
    const random = rng.random();

    var price: f64 = 100.0;
    for (data, 0..) |*row, i| {
        // Generate realistic price movement
        const change = (random.float(f64) - 0.5) * 4.0; // ±2% max change
        price += change;
        if (price < 1.0) price = 1.0;

        const volatility = random.float(f64) * 0.02; // 0-2% volatility
        const high = price * (1.0 + volatility);
        const low = price * (1.0 - volatility);

        row.* = .{
            .u64_timestamp = 1704067200 + i * 86400, // Daily data
            .f64_open = price,
            .f64_high = high,
            .f64_low = low,
            .f64_close = price,
            .u64_volume = 1000000 + random.uintAtMost(u64, 2000000),
        };
    }
    
    return data;
}

fn benchmarkIndicator(
    allocator: Allocator,
    comptime T: type,
    indicator: T,
    series: ohlcv.TimeSeries,
    name: []const u8,
    iterations: u32,
) !BenchmarkResult {
    const start_time = std.time.nanoTimestamp();
    
    for (0..iterations) |_| {
        var result = try indicator.calculate(series, allocator);
        result.deinit();
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration = @as(u64, @intCast(end_time - start_time));
    
    return BenchmarkResult{
        .name = name,
        .duration_ns = duration,
        .operations = iterations,
        .ns_per_op = @as(f64, @floatFromInt(duration)) / @as(f64, @floatFromInt(iterations)),
        .memory_used = 0, // Simplified memory tracking
    };
}

fn benchmarkMultiResultIndicator(
    allocator: Allocator,
    comptime T: type,
    indicator: T,
    series: ohlcv.TimeSeries,
    name: []const u8,
    iterations: u32,
) !BenchmarkResult {
    const start_time = std.time.nanoTimestamp();
    
    for (0..iterations) |_| {
        var result = try indicator.calculate(series, allocator);
        result.deinit();
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration = @as(u64, @intCast(end_time - start_time));
    
    return BenchmarkResult{
        .name = name,
        .duration_ns = duration,
        .operations = iterations,
        .ns_per_op = @as(f64, @floatFromInt(duration)) / @as(f64, @floatFromInt(iterations)),
        .memory_used = 0, // Simplified for multi-result indicators
    };
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var benchmark_suite = BenchmarkSuite.init(allocator);
    defer benchmark_suite.deinit();

    // Test different dataset sizes
    const dataset_sizes = [_]usize{ 100, 1000, 10000, 50000 };
    
    for (dataset_sizes) |size| {
        std.debug.print("Benchmarking with {} data points...\n", .{size});
        
        const test_data = try generateTestData(allocator, size);
        defer allocator.free(test_data);
        
        var series = try ohlcv.TimeSeries.fromSlice(allocator, test_data, false);
        defer series.deinit();

        const iterations: u32 = if (size <= 1000) 1000 else if (size <= 10000) 100 else 10;
        
        // Benchmark Simple Moving Average
        {
            const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
            const name = try std.fmt.allocPrint(allocator, "SMA-20 ({} points)", .{size});
            defer allocator.free(name);
            
            const result = try benchmarkIndicator(allocator, ohlcv.SmaIndicator, sma, series, name, iterations);
            try benchmark_suite.addResult(result);
        }

        // Benchmark Exponential Moving Average
        {
            const ema = ohlcv.EmaIndicator{ .u32_period = 20 };
            const name = try std.fmt.allocPrint(allocator, "EMA-20 ({} points)", .{size});
            defer allocator.free(name);
            
            const result = try benchmarkIndicator(allocator, ohlcv.EmaIndicator, ema, series, name, iterations);
            try benchmark_suite.addResult(result);
        }

        // Benchmark RSI
        {
            const rsi = ohlcv.RsiIndicator{ .u32_period = 14 };
            const name = try std.fmt.allocPrint(allocator, "RSI-14 ({} points)", .{size});
            defer allocator.free(name);
            
            const result = try benchmarkIndicator(allocator, ohlcv.RsiIndicator, rsi, series, name, iterations);
            try benchmark_suite.addResult(result);
        }

        // Benchmark Bollinger Bands
        {
            const bb = ohlcv.BollingerBandsIndicator{ .u32_period = 20 };
            const name = try std.fmt.allocPrint(allocator, "BB-20 ({} points)", .{size});
            defer allocator.free(name);
            
            const result = try benchmarkMultiResultIndicator(allocator, ohlcv.BollingerBandsIndicator, bb, series, name, iterations);
            try benchmark_suite.addResult(result);
        }

        // Benchmark MACD
        if (size >= 50) { // MACD needs more data
            const macd = ohlcv.MacdIndicator{ .u32_fast_period = 12, .u32_slow_period = 26, .u32_signal_period = 9 };
            const name = try std.fmt.allocPrint(allocator, "MACD ({} points)", .{size});
            defer allocator.free(name);
            
            const result = try benchmarkMultiResultIndicator(allocator, ohlcv.MacdIndicator, macd, series, name, iterations);
            try benchmark_suite.addResult(result);
        }

        // Benchmark ATR
        {
            const atr = ohlcv.AtrIndicator{ .u32_period = 14 };
            const name = try std.fmt.allocPrint(allocator, "ATR-14 ({} points)", .{size});
            defer allocator.free(name);
            
            const result = try benchmarkIndicator(allocator, ohlcv.AtrIndicator, atr, series, name, iterations);
            try benchmark_suite.addResult(result);
        }

        // Benchmark Stochastic
        if (size >= 25) { // Stochastic needs more data
            const stoch = ohlcv.StochasticIndicator{ .u32_k_period = 14, .u32_k_slowing = 3, .u32_d_period = 3 };
            const name = try std.fmt.allocPrint(allocator, "Stochastic ({} points)", .{size});
            defer allocator.free(name);
            
            const result = try benchmarkMultiResultIndicator(allocator, ohlcv.StochasticIndicator, stoch, series, name, iterations);
            try benchmark_suite.addResult(result);
        }
    }

    benchmark_suite.printResults();
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝