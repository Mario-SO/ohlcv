// ╔═══════════════════════════════════ Simple Benchmark ═════════════════════════════════════════╗

const std = @import("std");
const ohlcv = @import("ohlcv");
const print = std.debug.print;

fn generateTestData(allocator: std.mem.Allocator, size: usize) ![]ohlcv.OhlcvRow {
    const data = try allocator.alloc(ohlcv.OhlcvRow, size);

    var price: f64 = 100.0;
    for (data, 0..) |*row, i| {
        price += (@sin(@as(f64, @floatFromInt(i)) * 0.1) * 2.0);

        row.* = .{
            .u64_timestamp = 1704067200 + i * 86400,
            .f64_open = price,
            .f64_high = price + 2.0,
            .f64_low = price - 2.0,
            .f64_close = price + (@sin(@as(f64, @floatFromInt(i)) * 0.2)),
            .u64_volume = 1000000,
        };
    }

    return data;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("\n╔════════════════════════════════════════════════════════════════╗\n", .{});
    print("║                     OHLCV Benchmark Results                    ║\n", .{});
    print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    const sizes = [_]usize{ 1000, 10000 };

    for (sizes) |size| {
        print("📊 Dataset: {} data points\n", .{size});
        print("{s}\n", .{"─" ** 50});

        const test_data = try generateTestData(allocator, size);
        defer allocator.free(test_data);

        var series = try ohlcv.TimeSeries.fromSlice(allocator, test_data, false);
        defer series.deinit();

        // Benchmark SMA
        {
            const start = std.time.nanoTimestamp();
            const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
            var result = try sma.calculate(series, allocator);
            result.deinit();
            const end = std.time.nanoTimestamp();

            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
            print("SMA-20:        {d:>8.3} ms\n", .{duration_ms});
        }

        // Benchmark EMA
        {
            const start = std.time.nanoTimestamp();
            const ema = ohlcv.EmaIndicator{ .u32_period = 20 };
            var result = try ema.calculate(series, allocator);
            result.deinit();
            const end = std.time.nanoTimestamp();

            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
            print("EMA-20:        {d:>8.3} ms\n", .{duration_ms});
        }

        // Benchmark RSI
        {
            const start = std.time.nanoTimestamp();
            const rsi = ohlcv.RsiIndicator{ .u32_period = 14 };
            var result = try rsi.calculate(series, allocator);
            result.deinit();
            const end = std.time.nanoTimestamp();

            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
            print("RSI-14:        {d:>8.3} ms\n", .{duration_ms});
        }

        // Benchmark Bollinger Bands
        {
            const start = std.time.nanoTimestamp();
            const bb = ohlcv.BollingerBandsIndicator{ .u32_period = 20 };
            var result = try bb.calculate(series, allocator);
            result.deinit();
            const end = std.time.nanoTimestamp();

            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
            print("Bollinger-20:  {d:>8.3} ms\n", .{duration_ms});
        }

        // Benchmark MACD
        if (size >= 50) {
            const start = std.time.nanoTimestamp();
            const macd = ohlcv.MacdIndicator{};
            var result = try macd.calculate(series, allocator);
            result.deinit();
            const end = std.time.nanoTimestamp();

            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
            print("MACD:          {d:>8.3} ms\n", .{duration_ms});
        }

        // Benchmark ATR
        {
            const start = std.time.nanoTimestamp();
            const atr = ohlcv.AtrIndicator{ .u32_period = 14 };
            var result = try atr.calculate(series, allocator);
            result.deinit();
            const end = std.time.nanoTimestamp();

            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
            print("ATR-14:        {d:>8.3} ms\n", .{duration_ms});
        }

        print("\n", .{});
    }

    print("✅ Benchmarks completed successfully!\n", .{});
    print("💡 For detailed profiling, use: zig build profile-memory\n", .{});
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
