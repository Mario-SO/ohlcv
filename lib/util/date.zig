// ╔══════════════════════════════════════ Date Utilities (Internal) ══════════════════════════════════════╗

const std = @import("std");
const fmt = std.fmt;

// ┌──────────────────────────── Errors ────────────────────────────┐

/// Errors specific to date parsing (internal use).
pub const DateError = error{
    InvalidFormat,
    DateBeforeEpoch,
};

// └────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── yyyymmddToUnix ────────────────────────────┐

/// Parse a zero‑terminated or slice date string in `YYYY-MM-DD` format (UTC) to
/// seconds since Unix epoch (1970‑01‑01 00:00:00).
/// No timezone logic; only validates date is on or after the epoch.
pub fn yyyymmddToUnix(date_str: []const u8) DateError!u64 {
    if (date_str.len != 10 or date_str[4] != '-' or date_str[7] != '-')
        return DateError.InvalidFormat;

    const year: u16 = fmt.parseUnsigned(u16, date_str[0..4], 10) catch return DateError.InvalidFormat;
    const month: u8 = fmt.parseUnsigned(u8, date_str[5..7], 10) catch return DateError.InvalidFormat;
    const day: u8 = fmt.parseUnsigned(u8, date_str[8..10], 10) catch return DateError.InvalidFormat;

    if (year < 1970) return DateError.DateBeforeEpoch;
    if (month == 0 or month > 12 or day == 0) return DateError.InvalidFormat;

    const days_in_month = [_]u8{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

    var days_since_epoch: u64 = 0;

    // Leap year helper.
    const isLeap = struct {
        fn calc(y: u16) bool {
            return (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0);
        }
    }.calc;

    // Years
    var y: u16 = 1970;
    while (y < year) : (y += 1) {
        days_since_epoch += if (isLeap(y)) 366 else 365;
    }

    // Months within current year
    var m: u8 = 1;
    while (m < month) : (m += 1) {
        days_since_epoch += days_in_month[m];
        if (m == 2 and isLeap(year)) days_since_epoch += 1; // leap day
    }

    // Validate day vs month length
    var max_day_in_month = days_in_month[month];
    if (month == 2 and isLeap(year)) max_day_in_month += 1;
    if (day > max_day_in_month) return DateError.InvalidFormat;

    days_since_epoch += @as(u64, day) - 1;

    return days_since_epoch * 24 * 60 * 60;
}

// └──────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════════════════════╝
