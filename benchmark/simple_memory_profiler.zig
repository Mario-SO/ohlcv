// ╔════════════════════════════════════ Simple Memory Profiler ══════════════════════════════════╗

const std = @import("std");
const ohlcv = @import("ohlcv");

fn generateTestData(allocator: std.mem.Allocator, size: usize) ![]ohlcv.OhlcvRow {
    const data = try allocator.alloc(ohlcv.OhlcvRow, size);
    
    for (data, 0..) |*row, i| {
        const base_price = 100.0 + @sin(@as(f64, @floatFromInt(i)) * 0.1) * 20.0;
        row.* = .{
            .u64_timestamp = 1704067200 + i * 86400,
            .f64_open = base_price,
            .f64_high = base_price + 2.0,
            .f64_low = base_price - 2.0,
            .f64_close = base_price + @sin(@as(f64, @floatFromInt(i)) * 0.2),
            .u64_volume = 1000000,
        };
    }
    
    return data;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .verbose_log = false,
        .safety = true,
    }){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("🚨 Memory leak detected!\n", .{});
        } else {
            std.debug.print("✅ No memory leaks detected\n", .{});
        }
    }
    const allocator = gpa.allocator();

    std.debug.print("╔════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    OHLCV Memory Profile                       ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════╝\n", .{});

    const sizes = [_]usize{ 1000, 10000 };

    for (sizes) |size| {
        std.debug.print("\n🔍 Testing with {} data points\n", .{size});
        std.debug.print("{s}\n", .{"─" ** 40});

        const test_data = try generateTestData(allocator, size);
        defer allocator.free(test_data);
        
        var series = try ohlcv.TimeSeries.fromSlice(allocator, test_data, false);
        defer series.deinit();

        // Test SMA memory usage
        {
            const start_time = std.time.nanoTimestamp();
            const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
            var result = try sma.calculate(series, allocator);
            const end_time = std.time.nanoTimestamp();
            
            const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
            const result_size = result.arr_values.len;
            const memory_per_point = @as(f64, @floatFromInt(result_size * @sizeOf(f64) * 2)) / 1024.0; // values + timestamps
            
            std.debug.print("SMA-20:\n", .{});
            std.debug.print("  Duration: {d:>6.3} ms\n", .{duration_ms});
            std.debug.print("  Output points: {}\n", .{result_size});
            std.debug.print("  Memory used: ~{d:.2} KB\n", .{memory_per_point});
            
            result.deinit();
        }

        // Test Bollinger Bands memory usage (multi-result indicator)
        {
            const start_time = std.time.nanoTimestamp();
            const bb = ohlcv.BollingerBandsIndicator{ .u32_period = 20 };
            var result = try bb.calculate(series, allocator);
            const end_time = std.time.nanoTimestamp();
            
            const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
            const result_size = result.upper_band.arr_values.len;
            const memory_per_point = @as(f64, @floatFromInt(result_size * @sizeOf(f64) * 6)) / 1024.0; // 3 bands * 2 arrays each
            
            std.debug.print("Bollinger Bands:\n", .{});
            std.debug.print("  Duration: {d:>6.3} ms\n", .{duration_ms});
            std.debug.print("  Output points: {}\n", .{result_size});
            std.debug.print("  Memory used: ~{d:.2} KB (3 bands)\n", .{memory_per_point});
            
            result.deinit();
        }

        // Test CSV Parser memory usage
        if (size == 1000) { // Only test once
            const csv_data = 
                \\Date,Open,High,Low,Close,Volume
                \\2024-01-01,100.0,110.0,95.0,105.0,1000000
                \\2024-01-02,105.0,115.0,100.0,112.0,1200000
                \\2024-01-03,112.0,120.0,108.0,115.0,1100000
            ;

            const start_time = std.time.nanoTimestamp();
            const parser = ohlcv.CsvParser{ .allocator = allocator };
            var parsed_series = try parser.parse(csv_data);
            const end_time = std.time.nanoTimestamp();
            
            const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
            const csv_memory = @as(f64, @floatFromInt(parsed_series.len() * @sizeOf(ohlcv.OhlcvRow))) / 1024.0;
            
            std.debug.print("CSV Parser:\n", .{});
            std.debug.print("  Duration: {d:>6.3} ms\n", .{duration_ms});
            std.debug.print("  Parsed rows: {}\n", .{parsed_series.len()});
            std.debug.print("  Memory used: ~{d:.2} KB\n", .{csv_memory});
            
            parsed_series.deinit();
        }
    }

    std.debug.print("\n📊 Memory Profile Summary:\n", .{});
    std.debug.print("{s}\n", .{"─" ** 30});
    std.debug.print("• Single indicators (SMA, EMA, RSI): ~{d:.1} KB per 1K points\n", .{@as(f64, @floatFromInt(1000 * @sizeOf(f64) * 2)) / 1024.0});
    std.debug.print("• Multi-result indicators (BB, MACD): ~{d:.1} KB per 1K points\n", .{@as(f64, @floatFromInt(1000 * @sizeOf(f64) * 6)) / 1024.0});
    std.debug.print("• Raw OHLCV data: ~{d:.1} KB per 1K points\n", .{@as(f64, @floatFromInt(1000 * @sizeOf(ohlcv.OhlcvRow))) / 1024.0});
    
    std.debug.print("\n💡 Tips for optimization:\n", .{});
    std.debug.print("• Use streaming calculations for large datasets\n", .{});
    std.debug.print("• Pre-allocate result arrays when size is known\n", .{});
    std.debug.print("• Consider using memory pools for frequent calculations\n", .{});
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝