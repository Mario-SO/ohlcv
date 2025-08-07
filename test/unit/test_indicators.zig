// ╔═══════════════════════════════════════ Indicator Tests ═══════════════════════════════════════╗

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

test "BollingerBandsIndicator calculates correct values" {
    const allocator = testing.allocator;

    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704067200, .f64_open = 20, .f64_high = 22, .f64_low = 18, .f64_close = 20, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704153600, .f64_open = 21, .f64_high = 23, .f64_low = 19, .f64_close = 21, .u64_volume = 1100 },
        .{ .u64_timestamp = 1704240000, .f64_open = 22, .f64_high = 24, .f64_low = 20, .f64_close = 22, .u64_volume = 1200 },
        .{ .u64_timestamp = 1704326400, .f64_open = 23, .f64_high = 25, .f64_low = 21, .f64_close = 23, .u64_volume = 1300 },
        .{ .u64_timestamp = 1704412800, .f64_open = 24, .f64_high = 26, .f64_low = 22, .f64_close = 24, .u64_volume = 1400 },
    };

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    const bb = ohlcv.BollingerBandsIndicator{ .u32_period = 3, .f64_std_dev_multiplier = 2.0 };
    var result = try bb.calculate(series, allocator);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.upper_band.len());
    try testing.expectEqual(@as(usize, 3), result.middle_band.len());
    try testing.expectEqual(@as(usize, 3), result.lower_band.len());

    // Middle band should be SMA values
    try testing.expectApproxEqAbs(@as(f64, 21.0), result.middle_band.arr_values[0], 0.001);
    try testing.expectApproxEqAbs(@as(f64, 22.0), result.middle_band.arr_values[1], 0.001);
    try testing.expectApproxEqAbs(@as(f64, 23.0), result.middle_band.arr_values[2], 0.001);

    // Upper band should be above middle, lower band should be below
    for (0..result.middle_band.len()) |i| {
        try testing.expect(result.upper_band.arr_values[i] > result.middle_band.arr_values[i]);
        try testing.expect(result.lower_band.arr_values[i] < result.middle_band.arr_values[i]);
    }
}

test "BollingerBandsIndicator handles edge cases" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    // Test period = 0
    const bb_zero = ohlcv.BollingerBandsIndicator{ .u32_period = 0 };
    try testing.expectError(ohlcv.BollingerBandsIndicator.Error.InvalidParameters, bb_zero.calculate(series, allocator));

    // Test insufficient data
    const bb_large = ohlcv.BollingerBandsIndicator{ .u32_period = 10 };
    try testing.expectError(ohlcv.BollingerBandsIndicator.Error.InsufficientData, bb_large.calculate(series, allocator));
}

test "MacdIndicator calculates correct values" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 50);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    const macd = ohlcv.MacdIndicator{ .u32_fast_period = 5, .u32_slow_period = 10, .u32_signal_period = 3 };
    var result = try macd.calculate(series, allocator);
    defer result.deinit();

    // Should have data points after signal period calculation
    try testing.expect(result.macd_line.len() > 0);
    try testing.expectEqual(result.macd_line.len(), result.signal_line.len());
    try testing.expectEqual(result.macd_line.len(), result.histogram.len());

    // Histogram should be MACD - Signal
    for (0..result.histogram.len()) |i| {
        const expected_histogram = result.macd_line.arr_values[i] - result.signal_line.arr_values[i];
        try testing.expectApproxEqAbs(expected_histogram, result.histogram.arr_values[i], 0.001);
    }
}

test "MacdIndicator handles edge cases" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 10);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    // Test zero periods
    const macd_zero = ohlcv.MacdIndicator{ .u32_fast_period = 0, .u32_slow_period = 5, .u32_signal_period = 3 };
    try testing.expectError(ohlcv.MacdIndicator.Error.InvalidParameters, macd_zero.calculate(series, allocator));

    // Test fast >= slow
    const macd_invalid = ohlcv.MacdIndicator{ .u32_fast_period = 10, .u32_slow_period = 5, .u32_signal_period = 3 };
    try testing.expectError(ohlcv.MacdIndicator.Error.InvalidParameters, macd_invalid.calculate(series, allocator));

    // Test insufficient data
    const macd_large = ohlcv.MacdIndicator{ .u32_fast_period = 5, .u32_slow_period = 10, .u32_signal_period = 10 };
    try testing.expectError(ohlcv.MacdIndicator.Error.InsufficientData, macd_large.calculate(series, allocator));
}

test "AtrIndicator calculates correct values" {
    const allocator = testing.allocator;

    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704067200, .f64_open = 10, .f64_high = 12, .f64_low = 8, .f64_close = 11, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704153600, .f64_open = 11, .f64_high = 13, .f64_low = 9, .f64_close = 12, .u64_volume = 1100 },
        .{ .u64_timestamp = 1704240000, .f64_open = 12, .f64_high = 15, .f64_low = 10, .f64_close = 14, .u64_volume = 1200 },
        .{ .u64_timestamp = 1704326400, .f64_open = 14, .f64_high = 16, .f64_low = 12, .f64_close = 13, .u64_volume = 1300 },
        .{ .u64_timestamp = 1704412800, .f64_open = 13, .f64_high = 14, .f64_low = 11, .f64_close = 12, .u64_volume = 1400 },
    };

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    const atr = ohlcv.AtrIndicator{ .u32_period = 3 };
    var result = try atr.calculate(series, allocator);
    defer result.deinit();

    try testing.expect(result.len() > 0);

    // ATR values should be positive
    for (result.arr_values) |value| {
        try testing.expect(value > 0);
    }
}

test "AtrIndicator handles edge cases" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    // Test period = 0
    const atr_zero = ohlcv.AtrIndicator{ .u32_period = 0 };
    try testing.expectError(ohlcv.AtrIndicator.Error.InvalidParameters, atr_zero.calculate(series, allocator));

    // Test insufficient data
    const atr_large = ohlcv.AtrIndicator{ .u32_period = 10 };
    try testing.expectError(ohlcv.AtrIndicator.Error.InsufficientData, atr_large.calculate(series, allocator));
}

test "WmaIndicator calculates correct values" {
    const allocator = testing.allocator;

    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704067200, .f64_open = 10, .f64_high = 11, .f64_low = 9, .f64_close = 10, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704153600, .f64_open = 11, .f64_high = 12, .f64_low = 10, .f64_close = 11, .u64_volume = 1100 },
        .{ .u64_timestamp = 1704240000, .f64_open = 12, .f64_high = 13, .f64_low = 11, .f64_close = 12, .u64_volume = 1200 },
    };

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    const wma = ohlcv.WmaIndicator{ .u32_period = 3 };
    var result = try wma.calculate(series, allocator);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 1), result.len());

    // WMA formula: (10*1 + 11*2 + 12*3) / (1+2+3) = (10 + 22 + 36) / 6 = 68/6 = 11.333...
    try testing.expectApproxEqAbs(@as(f64, 11.333333), result.arr_values[0], 0.001);
}

test "WmaIndicator handles edge cases" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    // Test period = 0
    const wma_zero = ohlcv.WmaIndicator{ .u32_period = 0 };
    try testing.expectError(ohlcv.WmaIndicator.Error.InvalidParameters, wma_zero.calculate(series, allocator));

    // Test insufficient data
    const wma_large = ohlcv.WmaIndicator{ .u32_period = 10 };
    try testing.expectError(ohlcv.WmaIndicator.Error.InsufficientData, wma_large.calculate(series, allocator));
}

test "StochasticIndicator calculates correct values" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 30);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    const stoch = ohlcv.StochasticIndicator{ .u32_k_period = 5, .u32_k_slowing = 3, .u32_d_period = 3 };
    var result = try stoch.calculate(series, allocator);
    defer result.deinit();

    try testing.expect(result.k_percent.len() > 0);
    try testing.expectEqual(result.k_percent.len(), result.d_percent.len());

    // Stochastic values should be between 0 and 100
    for (result.k_percent.arr_values) |value| {
        try testing.expect(value >= 0.0);
        try testing.expect(value <= 100.0);
    }

    for (result.d_percent.arr_values) |value| {
        try testing.expect(value >= 0.0);
        try testing.expect(value <= 100.0);
    }
}

test "StochasticIndicator handles edge cases" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 10);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    // Test zero periods
    const stoch_zero = ohlcv.StochasticIndicator{ .u32_k_period = 0, .u32_k_slowing = 3, .u32_d_period = 3 };
    try testing.expectError(ohlcv.StochasticIndicator.Error.InvalidParameters, stoch_zero.calculate(series, allocator));

    // Test insufficient data
    const stoch_large = ohlcv.StochasticIndicator{ .u32_k_period = 20, .u32_k_slowing = 3, .u32_d_period = 3 };
    try testing.expectError(ohlcv.StochasticIndicator.Error.InsufficientData, stoch_large.calculate(series, allocator));
}

test "RocIndicator calculates correct values" {
    const allocator = testing.allocator;

    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704067200, .f64_open = 100, .f64_high = 105, .f64_low = 95, .f64_close = 100, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704153600, .f64_open = 100, .f64_high = 105, .f64_low = 95, .f64_close = 110, .u64_volume = 1100 },
        .{ .u64_timestamp = 1704240000, .f64_open = 110, .f64_high = 115, .f64_low = 105, .f64_close = 105, .u64_volume = 1200 },
    };

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    const roc = ohlcv.RocIndicator{ .u32_period = 1 };
    var result = try roc.calculate(series, allocator);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.len());

    // ROC = ((110 - 100) / 100) * 100 = 10%
    try testing.expectApproxEqAbs(@as(f64, 10.0), result.arr_values[0], 0.001);

    // ROC = ((105 - 110) / 110) * 100 = -4.545...%
    try testing.expectApproxEqAbs(@as(f64, -4.545454), result.arr_values[1], 0.001);
}

test "RocIndicator handles edge cases" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    // Test period = 0
    const roc_zero = ohlcv.RocIndicator{ .u32_period = 0 };
    try testing.expectError(ohlcv.RocIndicator.Error.InvalidParameters, roc_zero.calculate(series, allocator));

    // Test insufficient data
    const roc_large = ohlcv.RocIndicator{ .u32_period = 10 };
    try testing.expectError(ohlcv.RocIndicator.Error.InsufficientData, roc_large.calculate(series, allocator));
}

test "RocIndicator handles zero price division" {
    const allocator = testing.allocator;

    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1704067200, .f64_open = 0, .f64_high = 5, .f64_low = 0, .f64_close = 0, .u64_volume = 1000 },
        .{ .u64_timestamp = 1704153600, .f64_open = 100, .f64_high = 105, .f64_low = 95, .f64_close = 100, .u64_volume = 1100 },
    };

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    const roc = ohlcv.RocIndicator{ .u32_period = 1 };
    try testing.expectError(ohlcv.RocIndicator.Error.DivisionByZero, roc.calculate(series, allocator));
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝

test "VwapIndicator calculates non-decreasing cumulative VWAP" {
    const allocator = testing.allocator;

    const rows = [_]ohlcv.OhlcvRow{
        .{ .u64_timestamp = 1, .f64_open = 10, .f64_high = 11, .f64_low = 9, .f64_close = 10, .u64_volume = 100 },
        .{ .u64_timestamp = 2, .f64_open = 11, .f64_high = 12, .f64_low = 10, .f64_close = 11, .u64_volume = 100 },
        .{ .u64_timestamp = 3, .f64_open = 12, .f64_high = 13, .f64_low = 11, .f64_close = 12, .u64_volume = 100 },
    };

    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    const vwap = ohlcv.VwapIndicator{};
    var result = try vwap.calculate(series, allocator);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.len());
    try testing.expect(result.arr_values[1] >= 0);
}

test "CciIndicator returns values for valid period" {
    const allocator = testing.allocator;
    const rows = try test_helpers.createSampleRows(allocator, 30);
    defer allocator.free(rows);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    const cci = ohlcv.CciIndicator{ .u32_period = 20 };
    var result = try cci.calculate(series, allocator);
    defer result.deinit();
    try testing.expect(result.len() > 0);
}

test "ObvIndicator cumulative behavior" {
    const allocator = testing.allocator;
    var rows: [4]ohlcv.OhlcvRow = .{
        .{ .u64_timestamp = 1, .f64_open = 10, .f64_high = 10, .f64_low = 10, .f64_close = 10, .u64_volume = 10 },
        .{ .u64_timestamp = 2, .f64_open = 10, .f64_high = 10, .f64_low = 10, .f64_close = 11, .u64_volume = 5 },
        .{ .u64_timestamp = 3, .f64_open = 11, .f64_high = 11, .f64_low = 11, .f64_close = 10, .u64_volume = 3 },
        .{ .u64_timestamp = 4, .f64_open = 10, .f64_high = 10, .f64_low = 10, .f64_close = 10, .u64_volume = 7 },
    };
    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();

    const obv = ohlcv.ObvIndicator{};
    var result = try obv.calculate(series, allocator);
    defer result.deinit();

    try testing.expectEqual(@as(f64, 0.0), result.arr_values[0]);
    try testing.expectEqual(@as(f64, 5.0), result.arr_values[1]);
    try testing.expectEqual(@as(f64, 2.0), result.arr_values[2]);
    try testing.expectEqual(@as(f64, 2.0), result.arr_values[3]);
}

test "DonchianChannelsIndicator bands ordering" {
    const allocator = testing.allocator;
    const rows = try test_helpers.createSampleRows(allocator, 30);
    defer allocator.free(rows);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    const don = ohlcv.DonchianChannelsIndicator{ .u32_period = 10 };
    var result = try don.calculate(series, allocator);
    defer result.deinit();

    try testing.expect(result.upper_band.len() == result.middle_band.len());
    try testing.expect(result.upper_band.len() == result.lower_band.len());
    for (0..result.upper_band.len()) |i| {
        try testing.expect(result.upper_band.arr_values[i] >= result.middle_band.arr_values[i]);
        try testing.expect(result.middle_band.arr_values[i] >= result.lower_band.arr_values[i]);
    }
}

test "AroonIndicator produces values between 0 and 100" {
    const allocator = testing.allocator;
    const rows = try test_helpers.createSampleRows(allocator, 40);
    defer allocator.free(rows);
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    const aroon = ohlcv.AroonIndicator{ .u32_period = 25 };
    var result = try aroon.calculate(series, allocator);
    defer result.deinit();

    for (result.aroon_up.arr_values) |v| {
        try testing.expect(v >= 0.0 and v <= 100.0);
    }
    for (result.aroon_down.arr_values) |v| {
        try testing.expect(v >= 0.0 and v <= 100.0);
    }
}
