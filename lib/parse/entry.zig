const std = @import("std");
const print = std.debug.print;
const Row = @import("../core/row.zig").Row;
const state = @import("state.zig");
const fmt = std.fmt;
const mem = std.mem;
const time = std.time;

// Define custom errors for parsing
const ParseError = error{
    InvalidFormat, // General format error (e.g., wrong number of fields)
    InvalidTimestamp,
    InvalidOpen,
    InvalidHigh,
    InvalidLow,
    InvalidClose,
    InvalidVolume,
    InvalidDateFormat, // Added for custom date parsing
};

// Helper to check for leap year
fn isLeap(year: u16) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

// Helper to get days in month
const days_in_month = [_]u8{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

// Custom function to parse "YYYY-MM-DD" to Unix Timestamp (seconds since epoch)
// WARNING: Basic implementation, assumes UTC, no timezone handling.
fn parseDateToUnixTimestamp(date_str: []const u8) !u64 {
    if (date_str.len != 10 or date_str[4] != '-' or date_str[7] != '-') {
        return ParseError.InvalidDateFormat;
    }

    const year: u16 = fmt.parseUnsigned(u16, date_str[0..4], 10) catch return ParseError.InvalidDateFormat;
    const month: u8 = fmt.parseUnsigned(u8, date_str[5..7], 10) catch return ParseError.InvalidDateFormat;
    const day: u8 = fmt.parseUnsigned(u8, date_str[8..10], 10) catch return ParseError.InvalidDateFormat;

    if (year < 1970 or month == 0 or month > 12 or day == 0) {
        return ParseError.InvalidDateFormat; // Basic validation
    }

    var days_since_epoch: u64 = 0;

    // Add days for full years since epoch
    var y: u16 = 1970;
    while (y < year) : (y += 1) {
        days_since_epoch += if (isLeap(y)) 366 else 365;
    }

    // Add days for full months in the current year
    var m: u8 = 1;
    while (m < month) : (m += 1) {
        days_since_epoch += days_in_month[m];
        if (m == 2 and isLeap(year)) {
            days_since_epoch += 1; // Add leap day
        }
    }

    // Add days in the current month
    days_since_epoch += @as(u64, day) - 1;

    // Validate day for month
    var max_day_in_month = days_in_month[month];
    if (month == 2 and isLeap(year)) {
        max_day_in_month += 1;
    }
    if (day > max_day_in_month) {
        return ParseError.InvalidDateFormat;
    }

    const seconds_per_day: u64 = 24 * 60 * 60;
    return days_since_epoch * seconds_per_day;
}

// Helper function to parse a single line into a Row
fn parseLineToRow(line: []const u8) !Row {
    var fields = mem.splitScalar(u8, line, ',');
    var row: Row = undefined;

    // Helper to get next field or return error
    const nextField = struct {
        fn get(it: *mem.SplitIterator(u8, .scalar)) ![]const u8 {
            return it.next() orelse error.InvalidFormat;
        }
    }.get;

    // Parse Timestamp (YYYY-MM-DD)
    const ts_str = try nextField(&fields);
    row.ts = try parseDateToUnixTimestamp(ts_str);

    row.o = fmt.parseFloat(f64, try nextField(&fields)) catch |parse_err| {
        print("Open parsing error: {any}\n", .{parse_err}); // Optional logging
        return ParseError.InvalidOpen;
    };
    row.h = fmt.parseFloat(f64, try nextField(&fields)) catch |parse_err| {
        print("High parsing error: {any}\n", .{parse_err}); // Optional logging
        return ParseError.InvalidHigh;
    };
    row.l = fmt.parseFloat(f64, try nextField(&fields)) catch |parse_err| {
        print("Low parsing error: {any}\n", .{parse_err}); // Optional logging
        return ParseError.InvalidLow;
    };
    row.c = fmt.parseFloat(f64, try nextField(&fields)) catch |parse_err| {
        print("Close parsing error: {any}\n", .{parse_err}); // Optional logging
        return ParseError.InvalidClose;
    };
    row.v = fmt.parseUnsigned(u64, try nextField(&fields), 10) catch |parse_err| {
        print("Volume parsing error: {any}\n", .{parse_err}); // Optional logging
        return ParseError.InvalidVolume;
    };

    // Ensure no extra fields
    if (fields.next() != null) {
        return ParseError.InvalidFormat;
    }

    return row;
}

pub fn parseAll(alloc: std.mem.Allocator, reader: anytype) ![]Row {
    var rows = std.ArrayList(Row).init(alloc);
    errdefer rows.deinit(); // Ensure cleanup on error

    var line_buffer = std.ArrayList(u8).init(alloc);
    defer line_buffer.deinit();

    // Read and discard header line
    _ = reader.streamUntilDelimiter(line_buffer.writer(), '\n', null) catch |err| switch (err) {
        error.EndOfStream => return rows.toOwnedSlice(), // Empty or header-only file
        else => return err,
    };
    line_buffer.clearRetainingCapacity(); // Reuse buffer

    // Read and parse data lines
    while (true) {
        reader.streamUntilDelimiter(line_buffer.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break, // Normal end of file
            else => return err, // Propagate other read errors
        };

        const line = line_buffer.items;
        if (line.len == 0) { // Skip empty lines
            line_buffer.clearRetainingCapacity();
            continue;
        }

        const parsed_row = parseLineToRow(line) catch |err| {
            // Optional: Log the error and the problematic line
            print("Skipping invalid line: {s} - Error: {any}\n", .{ line, err });
            line_buffer.clearRetainingCapacity();
            continue; // Skip lines that fail to parse
        };

        try rows.append(parsed_row); // Append successfully parsed row
        line_buffer.clearRetainingCapacity(); // Clear buffer for next line
    }

    return rows.toOwnedSlice();
}
