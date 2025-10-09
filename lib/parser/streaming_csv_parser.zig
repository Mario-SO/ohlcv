// ╔════════════════════════════════════ Streaming CSV Parser ═════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const OhlcvRow = @import("../types/ohlcv_row.zig").OhlcvRow;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const date = @import("../utils/date.zig");
const ArrayList = std.array_list.Managed;

// ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

pub const ParseError = error{
    InvalidFormat,
    InvalidTimestamp,
    InvalidNumber,
    DateBeforeEpoch,
    OutOfMemory,
    EndOfStream,
};

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

/// Streaming CSV parser that processes data row-by-row to minimize memory usage
pub const StreamingCsvParser = struct {
    const Self = @This();
    const BUFFER_SIZE = 4096; // Process in 4KB chunks

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    allocator: Allocator,
    b_skip_header: bool = true,
    b_validate_data: bool = true,

    // Streaming state
    buffer: []u8,
    buffer_pos: usize = 0,
    buffer_end: usize = 0,
    line_buffer: ArrayList(u8),
    header_skipped: bool = false,
    stream_ended: bool = false,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────── Initialize Parser ─────────────────────────────────────────┐

    /// Initialize streaming parser
    pub fn init(allocator: Allocator) !Self {
        const buffer = try allocator.alloc(u8, BUFFER_SIZE);
        errdefer allocator.free(buffer);

        var line_buffer = ArrayList(u8).init(allocator);
        errdefer line_buffer.deinit();
        try line_buffer.ensureTotalCapacity(256); // Pre-allocate for typical line size

        return .{
            .allocator = allocator,
            .buffer = buffer,
            .line_buffer = line_buffer,
            .header_skipped = false,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
        self.line_buffer.deinit();
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────── Stream Processing Methods ────────────────────────────────────┐

    /// Process a chunk of data and yield rows one at a time
    pub fn feedData(self: *Self, data: []const u8) !void {
        if (self.stream_ended) return;

        // Copy as much data as possible to buffer
        const copy_len = @min(data.len, self.buffer.len - self.buffer_end);
        @memcpy(self.buffer[self.buffer_end .. self.buffer_end + copy_len], data[0..copy_len]);
        self.buffer_end += copy_len;
    }

    /// Get next row from stream (returns null when no more complete rows available)
    pub fn nextRow(self: *Self) !?OhlcvRow {
        while (true) {
            // Try to extract a complete line from buffer
            const line = try self.extractLine() orelse return null;
            defer self.allocator.free(line);

            // Skip header if needed
            if (!self.header_skipped and self.b_skip_header) {
                self.header_skipped = true;
                continue;
            }

            // Parse the line
            const row = parseLineFast(line) catch |err| {
                switch (err) {
                    ParseError.DateBeforeEpoch => continue,
                    ParseError.InvalidFormat => continue,
                    ParseError.InvalidTimestamp => continue,
                    ParseError.InvalidNumber => continue,
                    else => return err,
                }
            };

            // Validate if needed
            if (self.b_validate_data) {
                if (row.f64_open == 0 or row.f64_high == 0 or
                    row.f64_low == 0 or row.f64_close == 0 or row.u64_volume == 0)
                {
                    continue;
                }
            }

            return row;
        }
    }

    /// Signal end of data stream
    pub fn endStream(self: *Self) void {
        self.stream_ended = true;
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────────────── Helper Methods ─────────────────────────────────────────────┐

    /// Extract a complete line from buffer
    fn extractLine(self: *Self) !?[]u8 {
        self.line_buffer.clearRetainingCapacity();

        while (self.buffer_pos < self.buffer_end) {
            const byte = self.buffer[self.buffer_pos];
            self.buffer_pos += 1;

            if (byte == '\n' or byte == '\r') {
                // Skip consecutive line endings
                if (self.buffer_pos < self.buffer_end) {
                    const next_byte = self.buffer[self.buffer_pos];
                    if ((byte == '\r' and next_byte == '\n') or
                        (byte == '\n' and next_byte == '\r'))
                    {
                        self.buffer_pos += 1;
                    }
                }

                if (self.line_buffer.items.len > 0) {
                    return try self.allocator.dupe(u8, self.line_buffer.items);
                }
                continue;
            }

            try self.line_buffer.append(byte);
        }

        // Compact buffer if needed
        if (self.buffer_pos > 0) {
            const remaining = self.buffer_end - self.buffer_pos;
            std.mem.copyForwards(u8, self.buffer[0..remaining], self.buffer[self.buffer_pos..self.buffer_end]);
            self.buffer_end = remaining;
            self.buffer_pos = 0;
        }

        // Return line if stream ended and we have data
        if (self.stream_ended and self.line_buffer.items.len > 0) {
            return try self.allocator.dupe(u8, self.line_buffer.items);
        }

        return null;
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────── Batch Processing (Backward Compatibility) ────────────────────────────┐

    /// Parse all data at once (backward compatible with original parser)
    pub fn parse(self: *Self, data: []const u8) !TimeSeries {
        var rows = ArrayList(OhlcvRow).init(self.allocator);
        errdefer rows.deinit();

        // Feed all data at once
        var offset: usize = 0;
        while (offset < data.len) {
            const chunk_size = @min(BUFFER_SIZE, data.len - offset);
            try self.feedData(data[offset .. offset + chunk_size]);
            offset += chunk_size;

            // Process available rows
            while (try self.nextRow()) |row| {
                try rows.append(row);
            }
        }

        // Signal end and process remaining data
        self.endStream();
        while (try self.nextRow()) |row| {
            try rows.append(row);
        }

        const owned_rows = try rows.toOwnedSlice();
        return try TimeSeries.fromSlice(self.allocator, owned_rows, true);
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────── Parse a single CSV line ───────────────────────────────────┐

    /// Parse a single CSV line (shared with original parser for consistency)
    fn parseLineFast(line: []const u8) !OhlcvRow {
        var idx: usize = 0;
        var col: u8 = 0;
        var start: usize = 0;

        var date_slice: []const u8 = &[_]u8{};
        var open_slice: []const u8 = &[_]u8{};
        var high_slice: []const u8 = &[_]u8{};
        var low_slice: []const u8 = &[_]u8{};
        var close_slice: []const u8 = &[_]u8{};
        var volume_slice: []const u8 = &[_]u8{};

        while (idx <= line.len) : (idx += 1) {
            if (idx == line.len or line[idx] == ',') {
                const field = line[start..idx];
                if (col <= 5) {
                    switch (col) {
                        0 => date_slice = field,
                        1 => open_slice = field,
                        2 => high_slice = field,
                        3 => low_slice = field,
                        4 => close_slice = field,
                        5 => volume_slice = field,
                        else => unreachable,
                    }
                } else {
                    // ignore extra columns
                }
                col += 1;
                start = idx + 1;
            }
        }

        if (col < 6) return ParseError.InvalidFormat;

        const ts = date.parseDateYmd(date_slice) catch |e| switch (e) {
            error.InvalidTimestamp => return ParseError.InvalidTimestamp,
            error.DateBeforeEpoch => return ParseError.DateBeforeEpoch,
        };

        const open = std.fmt.parseFloat(f64, open_slice) catch return ParseError.InvalidNumber;
        const high = std.fmt.parseFloat(f64, high_slice) catch return ParseError.InvalidNumber;
        const low = std.fmt.parseFloat(f64, low_slice) catch return ParseError.InvalidNumber;
        const close = std.fmt.parseFloat(f64, close_slice) catch return ParseError.InvalidNumber;
        const volume = std.fmt.parseInt(u64, volume_slice, 10) catch return ParseError.InvalidNumber;

        return .{ .u64_timestamp = ts, .f64_open = open, .f64_high = high, .f64_low = low, .f64_close = close, .u64_volume = volume };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
