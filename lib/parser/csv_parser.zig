// ╔═════════════════════════════════════════ CSV Parser ══════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const OhlcvRow = @import("../types/ohlcv_row.zig").OhlcvRow;
const TimeSeries = @import("../time_series.zig").TimeSeries;

pub const ParseError = error{
    InvalidFormat,
    InvalidTimestamp,
    InvalidNumber,
    DateBeforeEpoch,
    OutOfMemory,
    EndOfStream,
};

pub const CsvParser = struct {
    const Self = @This();

    allocator: Allocator,
    b_skip_header: bool = true,
    b_validate_data: bool = true,

    /// Parse CSV data into TimeSeries
    pub fn parse(self: Self, data: []const u8) !TimeSeries {
        var rows = std.ArrayList(OhlcvRow).init(self.allocator);
        errdefer rows.deinit();

        // Pre-allocate based on estimated rows
        const estimated_rows = data.len / 50; // Rough estimate
        try rows.ensureTotalCapacity(estimated_rows);

        var line_iter = std.mem.tokenizeAny(u8, data, "\n\r");

        // Skip header if requested
        if (self.b_skip_header) {
            _ = line_iter.next();
        }

        while (line_iter.next()) |line| {
            if (line.len == 0) continue;

            const row = self.parseLine(line) catch |err| {
                // Skip invalid lines based on error type
                switch (err) {
                    ParseError.DateBeforeEpoch => continue,
                    ParseError.InvalidFormat => continue,
                    ParseError.InvalidTimestamp => continue,
                    ParseError.InvalidNumber => continue,
                    else => return err,
                }
            };

            // Validate data if requested
            if (self.b_validate_data) {
                if (row.f64_open == 0 or row.f64_high == 0 or
                    row.f64_low == 0 or row.f64_close == 0 or
                    row.u64_volume == 0)
                {
                    continue;
                }
            }

            try rows.append(row);
        }

        const owned_rows = try rows.toOwnedSlice();
        return try TimeSeries.fromSlice(self.allocator, owned_rows, true);
    }

    /// Parse a single CSV line
    fn parseLine(self: Self, line: []const u8) !OhlcvRow {
        _ = self;
        var fields = std.mem.tokenizeScalar(u8, line, ',');

        const date_str = fields.next() orelse return ParseError.InvalidFormat;
        const open_str = fields.next() orelse return ParseError.InvalidFormat;
        const high_str = fields.next() orelse return ParseError.InvalidFormat;
        const low_str = fields.next() orelse return ParseError.InvalidFormat;
        const close_str = fields.next() orelse return ParseError.InvalidFormat;
        const volume_str = fields.next() orelse return ParseError.InvalidFormat;

        return .{
            .u64_timestamp = try parseDate(date_str),
            .f64_open = std.fmt.parseFloat(f64, open_str) catch return ParseError.InvalidNumber,
            .f64_high = std.fmt.parseFloat(f64, high_str) catch return ParseError.InvalidNumber,
            .f64_low = std.fmt.parseFloat(f64, low_str) catch return ParseError.InvalidNumber,
            .f64_close = std.fmt.parseFloat(f64, close_str) catch return ParseError.InvalidNumber,
            .u64_volume = std.fmt.parseInt(u64, volume_str, 10) catch return ParseError.InvalidNumber,
        };
    }

    /// Parse YYYY-MM-DD to Unix timestamp
    fn parseDate(date_str: []const u8) !u64 {
        if (date_str.len != 10 or date_str[4] != '-' or date_str[7] != '-') {
            return ParseError.InvalidTimestamp;
        }

        const year = try std.fmt.parseInt(u16, date_str[0..4], 10);
        const month = try std.fmt.parseInt(u8, date_str[5..7], 10);
        const day = try std.fmt.parseInt(u8, date_str[8..10], 10);

        if (year < 1970) return ParseError.DateBeforeEpoch;
        if (month == 0 or month > 12 or day == 0 or day > 31) {
            return ParseError.InvalidTimestamp;
        }

        // Calculate days since epoch
        var days_since_epoch: u64 = 0;

        // Add years
        var y: u16 = 1970;
        while (y < year) : (y += 1) {
            days_since_epoch += if (isLeapYear(y)) 366 else 365;
        }

        // Add months
        const days_in_month = [_]u8{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        var m: u8 = 1;
        while (m < month) : (m += 1) {
            days_since_epoch += days_in_month[m];
            if (m == 2 and isLeapYear(year)) days_since_epoch += 1;
        }

        // Add days
        days_since_epoch += day - 1;

        return days_since_epoch * 24 * 60 * 60;
    }

    fn isLeapYear(year: u16) bool {
        return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
    }
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
