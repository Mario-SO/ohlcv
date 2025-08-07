// ╔══════════════════════════════════════════ Date Utils ══════════════════════════════════════════╗

const std = @import("std");

/// Parse YYYY-MM-DD to Unix timestamp (seconds since 1970-01-01 UTC)
/// - Validates month/day including leap years
pub fn parseDateYmd(date_str: []const u8) !u64 {
    if (date_str.len != 10 or date_str[4] != '-' or date_str[7] != '-') {
        return error.InvalidTimestamp;
    }

    const year = std.fmt.parseInt(u16, date_str[0..4], 10) catch return error.InvalidTimestamp;
    const month = std.fmt.parseInt(u8, date_str[5..7], 10) catch return error.InvalidTimestamp;
    const day = std.fmt.parseInt(u8, date_str[8..10], 10) catch return error.InvalidTimestamp;

    if (year < 1970) return error.DateBeforeEpoch;
    if (month == 0 or month > 12) return error.InvalidTimestamp;

    const mdays = daysInMonth(year, month);
    if (day == 0 or day > mdays) return error.InvalidTimestamp;

    // Calculate days since epoch
    var days_since_epoch: u64 = 0;

    // Add years
    var y: u16 = 1970;
    while (y < year) : (y += 1) {
        days_since_epoch += if (isLeapYear(y)) 366 else 365;
    }

    // Add months
    var m: u8 = 1;
    while (m < month) : (m += 1) {
        days_since_epoch += switch (m) {
            1, 3, 5, 7, 8, 10, 12 => 31,
            4, 6, 9, 11 => 30,
            2 => if (isLeapYear(year)) 29 else 28,
            else => unreachable,
        };
    }

    // Add days
    days_since_epoch += day - 1;

    return days_since_epoch * 24 * 60 * 60;
}

/// Return number of days in given month of year
pub fn daysInMonth(year: u16, month: u8) u8 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => 0,
    };
}

/// True if leap year per Gregorian rules
pub fn isLeapYear(year: u16) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
