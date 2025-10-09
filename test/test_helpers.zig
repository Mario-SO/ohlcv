// ╔════════════════════════════════════════ Test Helpers ═════════════════════════════════════════╗

const std = @import("std");
const ohlcv = @import("ohlcv");
const ArrayList = std.array_list.Managed;

/// Create sample OHLCV rows for testing
pub fn createSampleRows(allocator: std.mem.Allocator, count: usize) ![]ohlcv.OhlcvRow {
    const rows = try allocator.alloc(ohlcv.OhlcvRow, count);

    const base_timestamp: u64 = 1704067200; // 2024-01-01
    const day_seconds: u64 = 86400;

    for (rows, 0..) |*row, i| {
        const f_index = @as(f64, @floatFromInt(i));
        row.* = .{
            .u64_timestamp = base_timestamp + (i * day_seconds),
            .f64_open = 100.0 + f_index * 5.0,
            .f64_high = 110.0 + f_index * 5.0,
            .f64_low = 95.0 + f_index * 5.0,
            .f64_close = 105.0 + f_index * 5.0,
            .u64_volume = 1000000 + i * 100000,
        };
    }

    return rows;
}

/// Compare two OHLCV rows for equality
pub fn rowsEqual(a: ohlcv.OhlcvRow, b: ohlcv.OhlcvRow) bool {
    return a.u64_timestamp == b.u64_timestamp and
        @abs(a.f64_open - b.f64_open) < 0.001 and
        @abs(a.f64_high - b.f64_high) < 0.001 and
        @abs(a.f64_low - b.f64_low) < 0.001 and
        @abs(a.f64_close - b.f64_close) < 0.001 and
        a.u64_volume == b.u64_volume;
}

/// Compare floating point values with tolerance
pub fn floatEquals(a: f64, b: f64, tolerance: f64) bool {
    return @abs(a - b) < tolerance;
}

/// Generate CSV string from rows
pub fn rowsToCsv(allocator: std.mem.Allocator, rows: []const ohlcv.OhlcvRow) ![]u8 {
    var buffer = ArrayList(u8).init(allocator);
    var writer = buffer.writer();

    // Write header
    try writer.print("Date,Open,High,Low,Close,Volume\n", .{});

    // Write rows
    for (rows) |row| {
        const date = timestampToDate(row.u64_timestamp);
        try writer.print("{d:04}-{d:02}-{d:02},{d:.1},{d:.1},{d:.1},{d:.1},{d}\n", .{
            date.year,
            date.month,
            date.day,
            row.f64_open,
            row.f64_high,
            row.f64_low,
            row.f64_close,
            row.u64_volume,
        });
    }

    return buffer.toOwnedSlice();
}

const Date = struct {
    year: u16,
    month: u8,
    day: u8,
};

fn timestampToDate(timestamp: u64) Date {
    const days_since_epoch = timestamp / 86400;
    var remaining_days = days_since_epoch;

    var year: u16 = 1970;
    while (true) {
        const days_in_year: u64 = if (isLeapYear(year)) 366 else 365;
        if (remaining_days < days_in_year) break;
        remaining_days -= days_in_year;
        year += 1;
    }

    const days_in_month = [_]u8{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var month: u8 = 1;
    while (month <= 12) : (month += 1) {
        var days = days_in_month[month];
        if (month == 2 and isLeapYear(year)) days += 1;
        if (remaining_days < days) break;
        remaining_days -= days;
    }

    return .{
        .year = year,
        .month = month,
        .day = @intCast(remaining_days + 1),
    };
}

fn isLeapYear(year: u16) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
