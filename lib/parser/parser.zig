const std = @import("std");
const print = std.debug.print;
const Row = @import("../types/row.zig").Row;
const fmt = std.fmt;
const mem = std.mem;
const date_util = @import("../util/date.zig");
const ParseError = @import("../types/errors.zig").ParseError;

// Import the state machine from its own file
const StateMachineParser = @import("state_machine.zig").StateMachineParser;

// Helper function to parser a single line into a Row
fn parseLineToRow(line: []const u8) !Row {
    var fields = mem.splitScalar(u8, line, ',');
    var row: Row = undefined;

    // Helper to get next field or return error
    const nextField = struct {
        fn get(it: *mem.SplitIterator(u8, .scalar)) ![]const u8 {
            return it.next() orelse error.InvalidFormat;
        }
    }.get;

    // Parser Timestamp (YYYY-MM-DD)
    const ts_str = try nextField(&fields);
    row.ts = date_util.yyyymmddToUnix(ts_str) catch |err| switch (err) {
        date_util.DateError.DateBeforeEpoch => return ParseError.DateBeforeEpoch,
        date_util.DateError.InvalidFormat => return ParseError.InvalidDateFormat,
        else => return ParseError.InvalidTimestamp,
    };

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

    if (row.o == 0.0 or row.h == 0.0 or row.l == 0.0 or row.c == 0.0 or row.v == 0) {
        return ParseError.InvalidFormat;
    }

    return row;
}

// Parses all rows using std.mem.splitScalar (simpler, line-by-line)
pub fn parseCsv(alloc: std.mem.Allocator, reader: anytype) ![]Row {
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

    // Read and parser data lines
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
            // Skip lines with dates before epoch or other parsing errors
            if (err == error.DateBeforeEpoch) {
                // Optional: print("Skipping pre-1970 date line: {s}\n", .{line});
            } else {
                print("Skipping invalid line (parseCsv): {s} - Error: {any}\n", .{ line, err });
            }
            line_buffer.clearRetainingCapacity();
            continue;
        };

        try rows.append(parsed_row); // Append successfully parsed row
        line_buffer.clearRetainingCapacity(); // Clear buffer for next line
    }

    return rows.toOwnedSlice();
}

// Parses all rows using a byte-level state machine for field extraction
pub fn parseCsvFast(alloc: std.mem.Allocator, reader: anytype) ![]Row {
    var rows = std.ArrayList(Row).init(alloc);

    var parser = StateMachineParser.init(alloc, &rows) catch |err| {
        rows.deinit();
        return err;
    };
    defer parser.deinit();

    while (reader.readByte()) |byte| {
        parser.processByte(byte) catch |err| {
            rows.deinit();
            return err;
        };
    } else |err| {
        if (err != error.EndOfStream) {
            rows.deinit();
            return err;
        }
        try parser.finalize();
    }

    return rows.toOwnedSlice();
}
