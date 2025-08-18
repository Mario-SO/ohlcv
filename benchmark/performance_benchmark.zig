// ╔══════════════════════════════════ Optimization Benchmark ═════════════════════════════════════╗

const std = @import("std");
const ohlcv = @import("ohlcv");
const print = std.debug.print;

fn generateCsvData(allocator: std.mem.Allocator, rows: usize) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    try buffer.appendSlice("Date,Open,High,Low,Close,Volume\n");

    var price: f64 = 100.0;
    for (0..rows) |i| {
        price += (@sin(@as(f64, @floatFromInt(i)) * 0.1) * 2.0);
        const date = 1704067200 + i * 86400;

        const seconds_since_epoch = @as(i64, @intCast(date));
        const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(seconds_since_epoch) };
        const epoch_day = epoch_seconds.getEpochDay();
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();

        try buffer.writer().print("{d:0>4}-{d:0>2}-{d:0>2},{d:.2},{d:.2},{d:.2},{d:.2},{d}\n", .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            price,
            price + 2.0,
            price - 2.0,
            price + @sin(@as(f64, @floatFromInt(i)) * 0.2),
            1000000 + i * 100,
        });
    }

    return buffer.toOwnedSlice();
}

fn benchmarkIndicator(series: ohlcv.TimeSeries, allocator: std.mem.Allocator, name: []const u8) !void {
    const start = std.time.nanoTimestamp();

    const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
    var result = try sma.calculate(series, allocator);
    defer result.deinit();

    const end = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;

    print("  {s:<20} {d:>8.3} ms\n", .{ name, duration_ms });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("\n╔════════════════════════════════════════════════════════════════╗\n", .{});
    print("║                 Performance & Memory Benchmark                 ║\n", .{});
    print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    const test_sizes = [_]usize{ 1000, 10000, 50000 };

    for (test_sizes) |size| {
        print("\n🎯 Dataset Size: {} rows\n", .{size});
        print("{s}\n", .{"═" ** 65});

        const csv_data = try generateCsvData(allocator, size);
        defer allocator.free(csv_data);

        print("📁 CSV Size: {d:.2} KB\n\n", .{@as(f64, @floatFromInt(csv_data.len)) / 1024.0});

        // ─── Parser Benchmarks ───
        print("📊 Parser Performance:\n", .{});
        print("{s}\n", .{"─" ** 45});

        // Standard parsing
        {
            const start = std.time.nanoTimestamp();
            const parser = ohlcv.CsvParser{ .allocator = allocator };
            var series = try parser.parse(csv_data);
            defer series.deinit();
            const end = std.time.nanoTimestamp();

            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
            const throughput = @as(f64, @floatFromInt(series.len())) / duration_ms;

            print("  Standard Parse:\n", .{});
            print("    Time:       {d:>8.3} ms\n", .{duration_ms});
            print("    Throughput: {d:>8.0} rows/ms\n", .{throughput});
            print("    Rows:       {}\n\n", .{series.len()});
        }

        // With arena allocator
        {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();

            const start = std.time.nanoTimestamp();
            const parser = ohlcv.CsvParser{ .allocator = allocator };
            var series = try parser.parseWithArena(csv_data, &arena);
            defer series.deinit();
            const end = std.time.nanoTimestamp();

            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
            const throughput = @as(f64, @floatFromInt(series.len())) / duration_ms;

            print("  With Arena:\n", .{});
            print("    Time:       {d:>8.3} ms\n", .{duration_ms});
            print("    Throughput: {d:>8.0} rows/ms\n", .{throughput});
            print("    Rows:       {}\n\n", .{series.len()});
        }

        // ─── Memory Pool Benchmarks ───
        print("💾 Memory Pool Performance:\n", .{});
        print("{s}\n", .{"─" ** 45});

        // Parse data once for indicator tests
        const parser = ohlcv.CsvParser{ .allocator = allocator };
        var base_series = try parser.parse(csv_data);
        defer base_series.deinit();

        // Standard allocator
        {
            const start = std.time.nanoTimestamp();

            const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
            var sma_result = try sma.calculate(base_series, allocator);
            defer sma_result.deinit();

            const ema = ohlcv.EmaIndicator{ .u32_period = 20 };
            var ema_result = try ema.calculate(base_series, allocator);
            defer ema_result.deinit();

            const rsi = ohlcv.RsiIndicator{ .u32_period = 14 };
            var rsi_result = try rsi.calculate(base_series, allocator);
            defer rsi_result.deinit();

            const end = std.time.nanoTimestamp();
            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;

            print("  Standard Allocator:\n", .{});
            print("    3 indicators: {d:>8.3} ms\n\n", .{duration_ms});
        }

        // Memory pool allocator
        {
            var pool = ohlcv.MemoryPool.init(allocator);
            defer pool.deinit();
            const pool_allocator = pool.allocator();

            const start = std.time.nanoTimestamp();

            const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
            var sma_result = try sma.calculate(base_series, pool_allocator);
            defer sma_result.deinit();

            const ema = ohlcv.EmaIndicator{ .u32_period = 20 };
            var ema_result = try ema.calculate(base_series, pool_allocator);
            defer ema_result.deinit();

            const rsi = ohlcv.RsiIndicator{ .u32_period = 14 };
            var rsi_result = try rsi.calculate(base_series, pool_allocator);
            defer rsi_result.deinit();

            const end = std.time.nanoTimestamp();
            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;

            const stats = pool.getStats();

            print("  Memory Pool:\n", .{});
            print("    3 indicators: {d:>8.3} ms\n", .{duration_ms});
            print("    Pool stats:\n", .{});
            print("      Allocated: {d:.2} KB\n", .{@as(f64, @floatFromInt(stats.total_allocated)) / 1024.0});
            print("      Used:      {d:.2} KB\n", .{@as(f64, @floatFromInt(stats.total_used)) / 1024.0});
            print("      Pools:     {}\n\n", .{stats.pool_count});
        }

        // Indicator arena
        {
            var arena = try ohlcv.IndicatorArena.init(allocator);
            defer arena.deinit();
            const arena_allocator = arena.allocator();

            const start = std.time.nanoTimestamp();

            const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
            const sma_result = sma.calculate(base_series, arena_allocator) catch |err| {
                print("  Indicator Arena:\n", .{});
                print("    Skipped: {} (dataset too large for arena)\n", .{err});
                print("    Arena size:   8192 KB (fixed)\n\n", .{});
                break;
            };

            const ema = ohlcv.EmaIndicator{ .u32_period = 20 };
            const ema_result = try ema.calculate(base_series, arena_allocator);

            const rsi = ohlcv.RsiIndicator{ .u32_period = 14 };
            const rsi_result = try rsi.calculate(base_series, arena_allocator);

            const end = std.time.nanoTimestamp();
            const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;

            print("  Indicator Arena:\n", .{});
            print("    3 indicators: {d:>8.3} ms\n", .{duration_ms});
            print("    Arena size:   8192 KB (fixed)\n", .{});

            // Note: Not calling deinit on results since arena handles cleanup
            _ = sma_result;
            _ = ema_result;
            _ = rsi_result;
        }
    }

    print("\n" ++ "═" ** 65 ++ "\n", .{});
    print("✅ Performance benchmark completed!\n\n", .{});

    print("📈 Key Features:\n", .{});
    print("  • Fast CSV parser with optimized float/date parsing\n", .{});
    print("  • Memory pools for reduced allocation overhead\n", .{});
    print("  • Arena allocator for batch memory cleanup\n", .{});
    print("  • Streaming parser available for O(1) memory usage\n", .{});
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
