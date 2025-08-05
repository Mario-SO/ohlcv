// ╔══════════════════════════════════════ Indicator Tests ══════════════════════════════════════╗

const std = @import("std");
const testing = std.testing;
const ohlcv = @import("ohlcv");
const test_helpers = @import("test_helpers");

test "SmaIndicator calculates correct values" {
    const allocator = testing.allocator;
    
    // Create simple test data
    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704067200, .f64_open = 10, .f64_high = 11, .f64_low = 9, .f64_close = 10, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704153600, .f64_open = 11, .f64_high = 12, .f64_low = 10, .f64_close = 11, .u64_volume = 1100 },
        .{ .u64_timestamp = 1704240000, .f64_open = 12, .f64_high = 13, .f64_low = 11, .f64_close = 12, .u64_volume = 1200 },
        .{ .u64_timestamp = 1704326400, .f64_open = 13, .f64_high = 14, .f64_low = 12, .f64_close = 13, .u64_volume = 1300 },
        .{ .u64_timestamp = 1704412800, .f64_open = 14, .f64_high = 15, .f64_low = 13, .f64_close = 14, .u64_volume = 1400 },
    };
    
    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();
    
    const sma = ohlcv.SmaIndicator{ .u32_period = 3 };
    var result = try sma.calculate(series, allocator);
    defer result.deinit();
    
    try testing.expectEqual(@as(usize, 3), result.len());
    
    // SMA values should be:
    // (10 + 11 + 12) / 3 = 11
    // (11 + 12 + 13) / 3 = 12
    // (12 + 13 + 14) / 3 = 13
    try testing.expectApproxEqAbs(@as(f64, 11.0), result.arr_values[0], 0.001);
    try testing.expectApproxEqAbs(@as(f64, 12.0), result.arr_values[1], 0.001);
    try testing.expectApproxEqAbs(@as(f64, 13.0), result.arr_values[2], 0.001);
}

test "SmaIndicator handles edge cases" {
    const allocator = testing.allocator;
    
    const rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);
    
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();
    
    // Test period = 0
    const sma_zero = ohlcv.SmaIndicator{ .u32_period = 0 };
    try testing.expectError(ohlcv.SmaIndicator.Error.InvalidParameters, sma_zero.calculate(series, allocator));
    
    // Test insufficient data
    const sma_large = ohlcv.SmaIndicator{ .u32_period = 10 };
    try testing.expectError(ohlcv.SmaIndicator.Error.InsufficientData, sma_large.calculate(series, allocator));
}

test "EmaIndicator calculates correct values" {
    const allocator = testing.allocator;
    
    // Create test data with known values
    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704067200, .f64_open = 10, .f64_high = 11, .f64_low = 9, .f64_close = 10, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704153600, .f64_open = 11, .f64_high = 12, .f64_low = 10, .f64_close = 12, .u64_volume = 1100 },
        .{ .u64_timestamp = 1704240000, .f64_open = 12, .f64_high = 13, .f64_low = 11, .f64_close = 14, .u64_volume = 1200 },
        .{ .u64_timestamp = 1704326400, .f64_open = 13, .f64_high = 14, .f64_low = 12, .f64_close = 16, .u64_volume = 1300 },
        .{ .u64_timestamp = 1704412800, .f64_open = 14, .f64_high = 15, .f64_low = 13, .f64_close = 18, .u64_volume = 1400 },
    };
    
    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();
    
    const ema = ohlcv.EmaIndicator{ .u32_period = 3, .f64_smoothing = 2.0 };
    var result = try ema.calculate(series, allocator);
    defer result.deinit();
    
    try testing.expectEqual(@as(usize, 3), result.len());
    
    // First EMA should be SMA of first 3 values
    const first_sma = (10.0 + 12.0 + 14.0) / 3.0;
    try testing.expectApproxEqAbs(first_sma, result.arr_values[0], 0.001);
    
    // Subsequent values use EMA formula
    const multiplier = 2.0 / 4.0; // smoothing / (period + 1)
    const ema2 = (16.0 - first_sma) * multiplier + first_sma;
    try testing.expectApproxEqAbs(ema2, result.arr_values[1], 0.001);
}

test "RsiIndicator calculates correct values" {
    const allocator = testing.allocator;
    
    // Create data with known price changes
    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704067200, .f64_open = 44, .f64_high = 44, .f64_low = 44, .f64_close = 44.00, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704153600, .f64_open = 44, .f64_high = 44, .f64_low = 44, .f64_close = 44.34, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704240000, .f64_open = 44, .f64_high = 44, .f64_low = 44, .f64_close = 44.09, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704326400, .f64_open = 44, .f64_high = 44, .f64_low = 44, .f64_close = 43.61, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704412800, .f64_open = 44, .f64_high = 44, .f64_low = 44, .f64_close = 44.33, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704499200, .f64_open = 44, .f64_high = 44, .f64_low = 44, .f64_close = 44.83, .u64_volume = 1000 },
    };
    
    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();
    
    const rsi = ohlcv.RsiIndicator{ .u32_period = 3 };
    var result = try rsi.calculate(series, allocator);
    defer result.deinit();
    
    // With period 3, we get RSI values starting from index 3
    try testing.expect(result.len() > 0);
    
    // RSI should be between 0 and 100
    for (result.arr_values) |value| {
        try testing.expect(value >= 0.0);
        try testing.expect(value <= 100.0);
    }
}

test "RsiIndicator handles all gains scenario" {
    const allocator = testing.allocator;
    
    // Create data where price only goes up
    var rows: [10]ohlcv.OhlcvRow = undefined;
    for (&rows, 0..) |*row, i| {
        row.* = .{
            .u64_timestamp = 1704067200 + i * 86400,
            .f64_open = 100,
            .f64_high = 100,
            .f64_low = 100,
            .f64_close = 100.0 + @as(f64, @floatFromInt(i)),
            .u64_volume = 1000,
        };
    }
    
    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();
    
    const rsi = ohlcv.RsiIndicator{ .u32_period = 5 };
    var result = try rsi.calculate(series, allocator);
    defer result.deinit();
    
    // When all changes are gains, RSI should be close to 100
    try testing.expect(result.arr_values[result.len() - 1] > 95.0);
}

test "RsiIndicator handles all losses scenario" {
    const allocator = testing.allocator;
    
    // Create data where price only goes down
    var rows: [10]ohlcv.OhlcvRow = undefined;
    for (&rows, 0..) |*row, i| {
        row.* = .{
            .u64_timestamp = 1704067200 + i * 86400,
            .f64_open = 100,
            .f64_high = 100,
            .f64_low = 100,
            .f64_close = 100.0 - @as(f64, @floatFromInt(i)),
            .u64_volume = 1000,
        };
    }
    
    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();
    
    const rsi = ohlcv.RsiIndicator{ .u32_period = 5 };
    var result = try rsi.calculate(series, allocator);
    defer result.deinit();
    
    // When all changes are losses, RSI should be close to 0
    try testing.expect(result.arr_values[result.len() - 1] < 5.0);
}

test "All indicators return correct timestamps" {
    const allocator = testing.allocator;
    
    const rows = try test_helpers.createSampleRows(allocator, 10);
    defer allocator.free(rows);
    
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();
    
    // Test SMA timestamps
    const sma = ohlcv.SmaIndicator{ .u32_period = 3 };
    var sma_result = try sma.calculate(series, allocator);
    defer sma_result.deinit();
    
    try testing.expectEqual(rows[2].u64_timestamp, sma_result.arr_timestamps[0]);
    try testing.expectEqual(rows[9].u64_timestamp, sma_result.arr_timestamps[sma_result.len() - 1]);
    
    // Test EMA timestamps
    const ema = ohlcv.EmaIndicator{ .u32_period = 3 };
    var ema_result = try ema.calculate(series, allocator);
    defer ema_result.deinit();
    
    try testing.expectEqual(rows[2].u64_timestamp, ema_result.arr_timestamps[0]);
    
    // Test RSI timestamps
    const rsi = ohlcv.RsiIndicator{ .u32_period = 5 };
    var rsi_result = try rsi.calculate(series, allocator);
    defer rsi_result.deinit();
    
    try testing.expectEqual(rows[5].u64_timestamp, rsi_result.arr_timestamps[0]);
}

// ╚════════════════════════════════════════════════════════════════════════════════════════════╝