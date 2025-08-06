// ╔══════════════════════════════════════ Edge Case Tests ═══════════════════════════════════════╗

const std = @import("std");
const testing = std.testing;
const ohlcv = @import("ohlcv");
const test_helpers = @import("test_helpers");

test "TimeSeries handles empty data" {
    const allocator = testing.allocator;

    const rows: []ohlcv.OhlcvRow = &[_]ohlcv.OhlcvRow{};
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    try testing.expectEqual(@as(usize, 0), series.len());
}

test "TimeSeries handles single data point" {
    const allocator = testing.allocator;

    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704067200, .f64_open = 100, .f64_high = 105, .f64_low = 95, .f64_close = 102, .u64_volume = 1000 },
    };

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    try testing.expectEqual(@as(usize, 1), series.len());
    try testing.expectEqual(@as(u64, 1704067200), series.arr_rows[0].u64_timestamp);
}

test "Indicators handle extreme values" {
    const allocator = testing.allocator;

    // Create data with extreme values
    var rows: [10]ohlcv.OhlcvRow = undefined;
    for (&rows, 0..) |*row, i| {
        const base_value: f64 = if (i % 2 == 0) 1000000.0 else 0.001;
        row.* = .{
            .u64_timestamp = 1704067200 + i * 86400,
            .f64_open = base_value,
            .f64_high = base_value * 1.1,
            .f64_low = base_value * 0.9,
            .f64_close = base_value,
            .u64_volume = 1000,
        };
    }

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    // Test SMA with extreme values
    const sma = ohlcv.SmaIndicator{ .u32_period = 3 };
    var sma_result = try sma.calculate(series, allocator);
    defer sma_result.deinit();

    // Results should be finite
    for (sma_result.arr_values) |value| {
        try testing.expect(std.math.isFinite(value));
        try testing.expect(!std.math.isNan(value));
    }
}

test "Indicators handle identical values" {
    const allocator = testing.allocator;

    // Create data with identical values (no volatility)
    var rows: [10]ohlcv.OhlcvRow = undefined;
    for (&rows, 0..) |*row, i| {
        row.* = .{
            .u64_timestamp = 1704067200 + i * 86400,
            .f64_open = 100.0,
            .f64_high = 100.0,
            .f64_low = 100.0,
            .f64_close = 100.0,
            .u64_volume = 1000,
        };
    }

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    // Test Bollinger Bands with no volatility
    const bb = ohlcv.BollingerBandsIndicator{ .u32_period = 5 };
    var bb_result = try bb.calculate(series, allocator);
    defer bb_result.deinit();

    // All bands should be identical when there's no volatility
    for (0..bb_result.middle_band.len()) |i| {
        try testing.expectApproxEqAbs(@as(f64, 100.0), bb_result.upper_band.arr_values[i], 0.001);
        try testing.expectApproxEqAbs(@as(f64, 100.0), bb_result.middle_band.arr_values[i], 0.001);
        try testing.expectApproxEqAbs(@as(f64, 100.0), bb_result.lower_band.arr_values[i], 0.001);
    }

    // Test ATR with no volatility (should be zero)
    const atr = ohlcv.AtrIndicator{ .u32_period = 5 };
    var atr_result = try atr.calculate(series, allocator);
    defer atr_result.deinit();

    for (atr_result.arr_values) |value| {
        try testing.expectApproxEqAbs(@as(f64, 0.0), value, 0.001);
    }
}

test "CSV Parser handles malformed data gracefully" {
    const allocator = testing.allocator;

    // Test various malformed CSV scenarios
    const malformed_data =
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,105.0,115.0,100.0
        \\2024-01-03,not-a-number,120.0,108.0,115.0,1100000
        \\2024-01-04,,118.0,110.0,113.0,900000
        \\2024-01-05,115.0,118.0,110.0,113.0,900000,extra,column
    ;

    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var series = try parser.parse(malformed_data);
    defer series.deinit();

    // Should only parse valid rows (first and last)
    try testing.expectEqual(@as(usize, 2), series.len());
    try testing.expectEqual(@as(u64, 1704067200), series.arr_rows[0].u64_timestamp); // 2024-01-01
    try testing.expectEqual(@as(u64, 1704412800), series.arr_rows[1].u64_timestamp); // 2024-01-05
}

test "TimeSeries preserves data order" {
    const allocator = testing.allocator;

    // Create unsorted data
    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704326400, .f64_open = 13, .f64_high = 14, .f64_low = 12, .f64_close = 13, .u64_volume = 1300 }, // 2024-01-04
        .{ .u64_timestamp = 1704067200, .f64_open = 10, .f64_high = 11, .f64_low = 9, .f64_close = 10, .u64_volume = 1000 }, // 2024-01-01
        .{ .u64_timestamp = 1704240000, .f64_open = 12, .f64_high = 13, .f64_low = 11, .f64_close = 12, .u64_volume = 1200 }, // 2024-01-03
        .{ .u64_timestamp = 1704153600, .f64_open = 11, .f64_high = 12, .f64_low = 10, .f64_close = 11, .u64_volume = 1100 }, // 2024-01-02
    };

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);

    // Create series from unsorted data
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    // The library doesn't auto-sort, so let's verify data is in original order
    try testing.expectEqual(@as(u64, 1704326400), series.arr_rows[0].u64_timestamp); // 2024-01-04
    try testing.expectEqual(@as(u64, 1704067200), series.arr_rows[1].u64_timestamp); // 2024-01-01
    try testing.expectEqual(@as(u64, 1704240000), series.arr_rows[2].u64_timestamp); // 2024-01-03
    try testing.expectEqual(@as(u64, 1704153600), series.arr_rows[3].u64_timestamp); // 2024-01-02
}

test "Large dataset performance test" {
    const allocator = testing.allocator;

    // Create a large dataset
    const large_size = 1000;
    const large_rows = try allocator.alloc(ohlcv.OhlcvRow, large_size);
    defer allocator.free(large_rows);

    // Fill with sample data
    for (large_rows, 0..) |*row, i| {
        const base_price = 100.0 + @sin(@as(f64, @floatFromInt(i)) * 0.1) * 10.0;
        row.* = .{
            .u64_timestamp = 1704067200 + i * 86400,
            .f64_open = base_price,
            .f64_high = base_price + 2.0,
            .f64_low = base_price - 2.0,
            .f64_close = base_price + @sin(@as(f64, @floatFromInt(i)) * 0.2),
            .u64_volume = 1000 + i * 10,
        };
    }

    var series = try ohlcv.TimeSeries.fromSlice(allocator, large_rows, false);
    defer series.deinit();

    // Test various indicators on large dataset
    const start_time = std.time.nanoTimestamp();

    const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
    var sma_result = try sma.calculate(series, allocator);
    defer sma_result.deinit();

    const rsi = ohlcv.RsiIndicator{ .u32_period = 14 };
    var rsi_result = try rsi.calculate(series, allocator);
    defer rsi_result.deinit();

    const bb = ohlcv.BollingerBandsIndicator{ .u32_period = 20 };
    var bb_result = try bb.calculate(series, allocator);
    defer bb_result.deinit();

    const end_time = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

    // Performance should be reasonable (less than 100ms for this size)
    try testing.expect(duration_ms < 100.0);

    // Verify results are reasonable
    try testing.expect(sma_result.len() > 0);
    try testing.expect(rsi_result.len() > 0);
    try testing.expect(bb_result.upper_band.len() > 0);
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝