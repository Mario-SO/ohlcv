// ╔══════════════════════════════════════ Time Series Tests ══════════════════════════════════════╗

const std = @import("std");
const testing = std.testing;
const ohlcv = @import("ohlcv");
const test_helpers = @import("test_helpers");

test "TimeSeries.init creates empty series" {
    const allocator = testing.allocator;

    var series = ohlcv.TimeSeries.init(allocator);
    defer series.deinit();

    try testing.expectEqual(@as(usize, 0), series.len());
    try testing.expect(series.isEmpty());
}

test "TimeSeries.fromSlice creates series from data" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    try testing.expectEqual(@as(usize, 5), series.len());
    try testing.expect(!series.isEmpty());

    // Verify data was copied
    try testing.expect(test_helpers.rowsEqual(rows[0], series.arr_rows[0]));
    try testing.expect(test_helpers.rowsEqual(rows[4], series.arr_rows[4]));
}

test "TimeSeries.sliceByTime creates correct time window" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 10);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    // Slice to get days 3-7 (indices 2-6)
    const start_ts = rows[2].u64_timestamp;
    const end_ts = rows[6].u64_timestamp;

    const sliced = try series.sliceByTime(start_ts, end_ts);

    try testing.expectEqual(@as(usize, 5), sliced.len());
    try testing.expect(test_helpers.rowsEqual(rows[2], sliced.arr_rows[0]));
    try testing.expect(test_helpers.rowsEqual(rows[6], sliced.arr_rows[4]));
}

test "TimeSeries.filter filters rows correctly" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 10);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    // Filter for high volume days (> 1.3M)
    const filtered = try series.filter(struct {
        fn predicate(row: ohlcv.OhlcvRow) bool {
            return row.u64_volume > 1_300_000;
        }
    }.predicate);
    defer filtered.deinit();

    try testing.expectEqual(@as(usize, 6), filtered.len());

    // Verify all filtered rows meet criteria
    for (filtered.arr_rows) |row| {
        try testing.expect(row.u64_volume > 1_300_000);
    }
}

test "TimeSeries.sortByTime sorts unsorted data" {
    const allocator = testing.allocator;

    var rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);

    // Shuffle the rows
    const temp = rows[0];
    rows[0] = rows[4];
    rows[4] = rows[2];
    rows[2] = temp;

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    series.sortByTime();

    // Verify sorted order
    var i: usize = 1;
    while (i < series.len()) : (i += 1) {
        try testing.expect(series.arr_rows[i - 1].u64_timestamp < series.arr_rows[i].u64_timestamp);
    }
}

test "TimeSeries.iterator traverses all elements" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    var iter = series.iterator();
    var count: usize = 0;

    while (iter.next()) |row| {
        try testing.expect(test_helpers.rowsEqual(rows[count], row));
        count += 1;
    }

    try testing.expectEqual(@as(usize, 5), count);
}

test "TimeSeries.map transforms data correctly" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    const volumes = try series.map(u64, struct {
        fn getVolume(row: ohlcv.OhlcvRow) u64 {
            return row.u64_volume;
        }
    }.getVolume, allocator);
    defer allocator.free(volumes);

    try testing.expectEqual(@as(usize, 5), volumes.len);
    for (volumes, 0..) |volume, i| {
        try testing.expectEqual(rows[i].u64_volume, volume);
    }
}

test "TimeSeries.closePrices extracts closing prices" {
    const allocator = testing.allocator;

    const rows = try test_helpers.createSampleRows(allocator, 5);
    defer allocator.free(rows);

    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows, false);
    defer series.deinit();

    const prices = try series.closePrices(allocator);
    defer allocator.free(prices);

    try testing.expectEqual(@as(usize, 5), prices.len);
    for (prices, 0..) |price, i| {
        try testing.expect(test_helpers.floatEquals(rows[i].f64_close, price, 0.001));
    }
}

// ╚════════════════════════════════════════════════════════════════════════════════════════════╝
