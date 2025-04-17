// Internal State Machine for Fast CSV Parsing

const std = @import("std");
const fmt = std.fmt;
const Row = @import("../types/row.zig").Row;
const ParseError = @import("../types/errors.zig").ParseError;
const date_util = @import("../util/date.zig");

pub const StateMachineParser = struct {
    alloc: std.mem.Allocator,
    rows: *std.ArrayList(Row),
    field_buffer: std.ArrayList(u8),
    current_row: Row = undefined,
    field_index: u8 = 0,
    is_header: bool = true,
    is_skipping_current_line: bool = false,

    pub fn init(alloc: std.mem.Allocator, rows_list: *std.ArrayList(Row)) !StateMachineParser {
        var field_buffer = std.ArrayList(u8).init(alloc);
        errdefer field_buffer.deinit();
        return StateMachineParser{
            .alloc = alloc,
            .rows = rows_list,
            .field_buffer = field_buffer,
        };
    }

    pub fn deinit(self: *StateMachineParser) void {
        self.field_buffer.deinit();
    }

    // Processes the end of a field
    fn processFieldEnd(self: *StateMachineParser) !void {
        const field_bytes = self.field_buffer.items;

        if (!self.is_header) {
            switch (self.field_index) {
                0 => { // Timestamp
                    if (field_bytes.len != 10) return ParseError.InvalidDateFormat;
                    const ts_or_err = date_util.yyyymmddToUnix(field_bytes[0..10]);

                    if (ts_or_err) |ts| {
                        self.current_row.ts = ts;
                    } else |err| {
                        switch (err) {
                            date_util.DateError.DateBeforeEpoch => {
                                self.is_skipping_current_line = true;
                            },
                            date_util.DateError.InvalidFormat => return ParseError.InvalidDateFormat,
                        }
                    }
                    if (self.is_skipping_current_line) {
                        self.field_buffer.clearRetainingCapacity();
                        self.field_index += 1;
                        return;
                    }
                },
                1 => { // Open
                    self.current_row.o = fmt.parseFloat(f64, field_bytes) catch |e| {
                        std.debug.print("State Machine: Open parsing error on '{s}': {any}\n", .{ field_bytes, e });
                        return error.InvalidOpen;
                    };
                },
                2 => { // High
                    self.current_row.h = fmt.parseFloat(f64, field_bytes) catch |e| {
                        std.debug.print("State Machine: High parsing error on '{s}': {any}\n", .{ field_bytes, e });
                        return error.InvalidHigh;
                    };
                },
                3 => { // Low
                    self.current_row.l = fmt.parseFloat(f64, field_bytes) catch |e| {
                        std.debug.print("State Machine: Low parsing error on '{s}': {any}\n", .{ field_bytes, e });
                        return error.InvalidLow;
                    };
                },
                4 => { // Close
                    self.current_row.c = fmt.parseFloat(f64, field_bytes) catch |e| {
                        std.debug.print("State Machine: Close parsing error on '{s}': {any}\n", .{ field_bytes, e });
                        return error.InvalidClose;
                    };
                },
                5 => { // Volume
                    self.current_row.v = fmt.parseUnsigned(u64, field_bytes, 10) catch |e| {
                        std.debug.print("State Machine: Volume parsing error on '{s}': {any}\n", .{ field_bytes, e });
                        return error.InvalidVolume;
                    };
                },
                else => {
                    std.debug.print("State Machine: Too many fields in row.\n", .{});
                    return error.InvalidFormat;
                },
            }
        }

        self.field_buffer.clearRetainingCapacity();
        self.field_index += 1;
    }

    // Processes the end of a row
    fn processRowEnd(self: *StateMachineParser) !void {
        if (self.is_skipping_current_line) return;

        if (self.field_index != 6) {
            if (!(self.field_index == 1 and self.field_buffer.items.len == 0 and !self.is_header)) {
                std.debug.print("State Machine: Incorrect number of fields ({d}) in row ending with newline.\n", .{self.field_index});
                return error.InvalidFormat;
            }
        }

        if (!self.is_header) {
            if (self.field_index == 6 and
                self.current_row.o != 0.0 and self.current_row.h != 0.0 and
                self.current_row.l != 0.0 and self.current_row.c != 0.0 and
                self.current_row.v != 0)
            {
                try self.rows.append(self.current_row);
            } else if (self.field_index == 6) {
                // Skip zero rows silently
            } else {
                // Allowed empty trailing line
            }
        } else {
            self.is_header = false;
        }

        self.field_index = 0;
        self.current_row = undefined;
        self.field_buffer.clearRetainingCapacity();
    }

    // Processes a single byte
    pub fn processByte(self: *StateMachineParser, byte: u8) !void {
        if (self.is_skipping_current_line) {
            if (byte == '\n') {
                self.is_skipping_current_line = false;
                self.field_index = 0;
                self.field_buffer.clearRetainingCapacity();
                self.current_row = undefined;
            }
            return;
        }

        switch (byte) {
            ',' => try self.processFieldEnd(),
            '\n' => {
                if (self.field_buffer.items.len > 0 or self.field_index > 0) {
                    try self.processFieldEnd();
                    if (self.is_skipping_current_line) return;
                }
                try self.processRowEnd();
            },
            '\r' => {}, // Ignore CR
            else => try self.field_buffer.append(byte),
        }
    }

    // Handles the end of the input stream (EOF)
    pub fn finalize(self: *StateMachineParser) !void {
        if (self.is_skipping_current_line) return;

        if (self.field_buffer.items.len > 0) {
            if (!self.is_header and self.field_index == 5) {
                try self.processFieldEnd();
                if (self.is_skipping_current_line) return;
            } else if (self.is_header and self.field_index > 0) {
                self.field_index += 1;
            } else if (!self.is_header and self.field_index < 5) {
                std.debug.print("State Machine: Incomplete row at EOF ({d} fields).\n", .{self.field_index + 1});
                return error.InvalidFormat;
            }
        }

        if (!self.is_header and self.field_index == 6) {
            if (self.current_row.o != 0.0 and self.current_row.h != 0.0 and
                self.current_row.l != 0.0 and self.current_row.c != 0.0 and
                self.current_row.v != 0)
            {
                try self.rows.append(self.current_row);
            }
        } else if (!self.is_header and self.field_index != 0) {
            if (self.field_buffer.items.len > 0) {
                std.debug.print("State Machine: Incomplete final row ({d} fields) at EOF with data in buffer.\n", .{self.field_index});
                return error.InvalidFormat;
            }
        }
    }
};
