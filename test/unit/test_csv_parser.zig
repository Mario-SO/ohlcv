// ╔══════════════════════════════════════ CSV Parser Tests ═══════════════════════════════════════╗

const std = @import("std");
const testing = std.testing;
const ohlcv = @import("ohlcv");
const test_helpers = @import("test_helpers");

test "CsvParser parses valid CSV correctly" {
    const allocator = testing.allocator;

    const csv_data =
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,105.0,115.0,100.0,112.0,1200000
        \\2024-01-03,112.0,120.0,108.0,115.0,1100000
    ;

    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var series = try parser.parse(csv_data);
    defer series.deinit();

    try testing.expectEqual(@as(usize, 3), series.len());

    // Check first row
    const row1 = series.arr_rows[0];
    try testing.expectEqual(@as(u64, 1704067200), row1.u64_timestamp); // 2024-01-01
    try testing.expectApproxEqAbs(@as(f64, 100.0), row1.f64_open, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 110.0), row1.f64_high, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 95.0), row1.f64_low, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 105.0), row1.f64_close, 0.001);
    try testing.expectEqual(@as(u64, 1000000), row1.u64_volume);
}

test "CsvParser skips header when configured" {
    const allocator = testing.allocator;

    const csv_data =
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
    ;

    const parser = ohlcv.CsvParser{
        .allocator = allocator,
        .b_skip_header = true,
    };
    var series = try parser.parse(csv_data);
    defer series.deinit();

    try testing.expectEqual(@as(usize, 1), series.len());
}

test "CsvParser handles empty lines" {
    const allocator = testing.allocator;

    const csv_data =
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\
        \\2024-01-02,105.0,115.0,100.0,112.0,1200000
        \\
        \\
    ;

    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var series = try parser.parse(csv_data);
    defer series.deinit();

    try testing.expectEqual(@as(usize, 2), series.len());
}

test "CsvParser skips invalid rows" {
    const allocator = testing.allocator;

    const csv_data =
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\invalid-date,105.0,115.0,100.0,112.0,1200000
        \\2024-01-03,not-a-number,120.0,108.0,115.0,1100000
        \\2024-01-04,115.0,118.0,110.0,113.0,900000
    ;

    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var series = try parser.parse(csv_data);
    defer series.deinit();

    // Should have only 2 valid rows
    try testing.expectEqual(@as(usize, 2), series.len());

    // Verify the valid rows
    try testing.expectEqual(@as(u64, 1704067200), series.arr_rows[0].u64_timestamp);
    try testing.expectEqual(@as(u64, 1704326400), series.arr_rows[1].u64_timestamp);
}

test "CsvParser validates data when configured" {
    const allocator = testing.allocator;

    const csv_data =
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,0.0,115.0,100.0,112.0,1200000
        \\2024-01-03,112.0,120.0,108.0,0.0,1100000
        \\2024-01-04,115.0,118.0,110.0,113.0,0
        \\2024-01-05,120.0,125.0,118.0,122.0,1500000
    ;

    const parser = ohlcv.CsvParser{
        .allocator = allocator,
        .b_validate_data = true,
    };
    var series = try parser.parse(csv_data);
    defer series.deinit();

    // Should skip rows with zero values
    try testing.expectEqual(@as(usize, 2), series.len());

    // Verify remaining rows have non-zero values
    for (series.arr_rows) |row| {
        try testing.expect(row.f64_open != 0);
        try testing.expect(row.f64_high != 0);
        try testing.expect(row.f64_low != 0);
        try testing.expect(row.f64_close != 0);
        try testing.expect(row.u64_volume != 0);
    }
}

test "CsvParser handles dates before epoch" {
    const allocator = testing.allocator;

    const csv_data =
        \\Date,Open,High,Low,Close,Volume
        \\1969-12-31,100.0,110.0,95.0,105.0,1000000
        \\2024-01-01,105.0,115.0,100.0,112.0,1200000
    ;

    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var series = try parser.parse(csv_data);
    defer series.deinit();

    // Should skip pre-1970 date
    try testing.expectEqual(@as(usize, 1), series.len());
    try testing.expectEqual(@as(u64, 1704067200), series.arr_rows[0].u64_timestamp);
}

test "CsvParser handles various line endings" {
    const allocator = testing.allocator;

    const csv_data = "Date,Open,High,Low,Close,Volume\r\n" ++
        "2024-01-01,100.0,110.0,95.0,105.0,1000000\r" ++
        "2024-01-02,105.0,115.0,100.0,112.0,1200000\n" ++
        "2024-01-03,112.0,120.0,108.0,115.0,1100000\r\n";

    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var series = try parser.parse(csv_data);
    defer series.deinit();

    try testing.expectEqual(@as(usize, 3), series.len());
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
