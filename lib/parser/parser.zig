const std = @import("std");
const print = std.debug.print;
const Row = @import("../types/row.zig").Row;
const fmt = std.fmt;
const mem = std.mem;
const date_util = @import("../util/date.zig");
const ParseError = @import("../types/errors.zig").ParseError;

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
    errdefer rows.deinit();

    var field_buffer = std.ArrayList(u8).init(alloc);
    defer field_buffer.deinit();

    var current_row: Row = undefined;
    var field_index: u8 = 0;
    var is_header = true;

    while (reader.readByte()) |byte| {
        switch (byte) {
            ',', '\n' => {
                // End of a field
                const field_bytes = field_buffer.items;

                // Skip parsing for header row, but still count fields
                if (!is_header) {
                    switch (field_index) {
                        0 => {
                            // print("DEBUG: Parsing date field: '{s}'\n", .{field_bytes});
                            current_row.ts = date_util.yyyymmddToUnix(field_bytes) catch |err| switch (err) {
                                date_util.DateError.DateBeforeEpoch => {
                                    // Date is pre-1970. Skip the rest of this line.
                                    // Optional: print("Skipping pre-1970 date row starting with: {s}\n", .{field_bytes});
                                    while (reader.readByte()) |byte_to_skip| {
                                        if (byte_to_skip == '\n') break; // Found end of line
                                    } else |skip_err| {
                                        if (skip_err != error.EndOfStream) return skip_err; // Propagate real read errors
                                        break; // EOF while skipping line
                                    }
                                    // Reset state for the next line and continue outer loop
                                    field_index = 0;
                                    field_buffer.clearRetainingCapacity();
                                    continue; // Continue the main while loop (skips rest of current row logic)
                                },
                                date_util.DateError.InvalidFormat => return ParseError.InvalidDateFormat,
                                // No else needed: all cases handled
                            };
                        },
                        1 => {
                            const value = fmt.parseFloat(f64, field_bytes) catch |e| {
                                print("State Machine: Open parsing error on '{s}': {any}\n", .{ field_bytes, e });
                                return error.InvalidOpen;
                            };
                            current_row.o = value;
                        },
                        2 => {
                            const value = fmt.parseFloat(f64, field_bytes) catch |e| {
                                print("State Machine: High parsing error on '{s}': {any}\n", .{ field_bytes, e });
                                return error.InvalidHigh;
                            };
                            current_row.h = value;
                        },
                        3 => {
                            const value = fmt.parseFloat(f64, field_bytes) catch |e| {
                                print("State Machine: Low parsing error on '{s}': {any}\n", .{ field_bytes, e });
                                return error.InvalidLow;
                            };
                            current_row.l = value;
                        },
                        4 => {
                            const value = fmt.parseFloat(f64, field_bytes) catch |e| {
                                print("State Machine: Close parsing error on '{s}': {any}\n", .{ field_bytes, e });
                                return error.InvalidClose;
                            };
                            current_row.c = value;
                        },
                        5 => {
                            const value = fmt.parseUnsigned(u64, field_bytes, 10) catch |e| {
                                print("State Machine: Volume parsing error on '{s}': {any}\n", .{ field_bytes, e });
                                return error.InvalidVolume;
                            };
                            current_row.v = value;
                        },
                        else => {
                            print("State Machine: Too many fields in row.\n", .{});
                            return error.InvalidFormat;
                        },
                    }
                }

                field_buffer.clearRetainingCapacity(); // Reset for next field
                field_index += 1;

                if (byte == '\n') {
                    // End of a row
                    if (field_index != 6) {
                        // Allow empty last line after valid rows
                        if (field_index == 1 and field_buffer.items.len == 0 and !is_header) {
                            break;
                        } else {
                            print("State Machine: Incorrect number of fields ({d}) in row.\n", .{field_index});
                            return error.InvalidFormat;
                        }
                    }

                    if (!is_header) {
                        if (!(current_row.o == 0.0 or current_row.h == 0.0 or current_row.l == 0.0 or current_row.c == 0.0 or current_row.v == 0)) {
                            try rows.append(current_row);
                        }
                    } else {
                        is_header = false; // Finished header row
                    }

                    // Reset field index and row *after* potential append/skip
                    field_index = 0;
                    current_row = undefined;
                }
            },
            else => {
                // Part of the current field
                try field_buffer.append(byte);
            },
        }
    } else |err| {
        if (err != error.EndOfStream) {
            return err; // Propagate read errors
        }
        // Handle case where file ends *without* a trailing newline after the last field
        if (field_buffer.items.len > 0) {
            if (!is_header and field_index == 5) { // Check if we have a complete final field (volume)
                const value = fmt.parseUnsigned(u64, field_buffer.items, 10) catch |e| {
                    print("State Machine: Volume parsing error on trailing field '{s}': {any}\n", .{ field_buffer.items, e });
                    return error.InvalidVolume;
                };
                current_row.v = value;
                field_index += 1;
            } else if (!is_header and field_index < 5) {
                print("State Machine: Incomplete row at EOF.\n", .{});
                return error.InvalidFormat;
            } else if (is_header and field_index > 0) { // File has only header
                is_header = false;
            }
        }
        // Append the last row if it was fully processed before EOF
        // If field_index reached 6, the date was already validated (not pre-1970)
        // in the main loop's date parsing step.
        if (!is_header and field_index == 6) {
            if (!(current_row.o == 0.0 or current_row.h == 0.0 or current_row.l == 0.0 or current_row.c == 0.0 or current_row.v == 0)) {
                try rows.append(current_row);
            }
        } else if (!is_header and field_index != 0) {
            // Don't append incomplete rows at EOF unless it's just an empty line
            if (field_index != 1 or field_buffer.items.len > 0) {
                print("State Machine: Incomplete final row ({d} fields) at EOF.\n", .{field_index});
                return error.InvalidFormat;
            }
        }
    }

    return rows.toOwnedSlice();
}
