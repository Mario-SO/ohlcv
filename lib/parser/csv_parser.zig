// ╔═════════════════════════════════════════ CSV Parser ══════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const OhlcvRow = @import("../types/ohlcv_row.zig").OhlcvRow;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const fast = @import("fast_parser.zig");
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

/// High-performance CSV parser using optimized parsing routines
pub const CsvParser = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    allocator: Allocator,
    b_skip_header: bool = true,
    b_validate_data: bool = true,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────── Parse CSV data into TimeSeries ────────────────────────────────┐

    /// Parse CSV data into TimeSeries using optimized parsing
    pub fn parse(self: Self, data: []const u8) !TimeSeries {
        var rows = ArrayList(OhlcvRow).init(self.allocator);
        errdefer rows.deinit();

        // Pre-count lines for exact allocation
        const line_count = fast.countNewlines(data) + 1;
        const capacity = if (self.b_skip_header and line_count > 0) line_count - 1 else line_count;
        try rows.ensureTotalCapacity(capacity);

        var it = std.mem.splitAny(u8, data, "\r\n");
        var header_skipped = !self.b_skip_header;

        while (it.next()) |line| {
            if (line.len == 0) continue;
            if (!header_skipped) {
                header_skipped = true;
                continue;
            }

            const row = parseLine(line) catch |err| {
                switch (err) {
                    ParseError.DateBeforeEpoch => continue,
                    ParseError.InvalidFormat => continue,
                    ParseError.InvalidTimestamp => continue,
                    ParseError.InvalidNumber => continue,
                    else => return err,
                }
            };

            if (self.b_validate_data) {
                if (row.f64_open == 0 or row.f64_high == 0 or
                    row.f64_low == 0 or row.f64_close == 0 or row.u64_volume == 0)
                {
                    continue;
                }
            }

            try rows.append(row);
        }

        const owned_rows = try rows.toOwnedSlice();
        return try TimeSeries.fromSlice(self.allocator, owned_rows, true);
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Optimized Line Parsing ───────────────────────────────────────────┐

    /// Parse a single CSV line using fast parsing routines
    fn parseLine(line: []const u8) !OhlcvRow {
        var splitter = fast.LineSplitter{ .line = line };

        // Extract fields
        const date_field = splitter.nextField() orelse return ParseError.InvalidFormat;
        const open_field = splitter.nextField() orelse return ParseError.InvalidFormat;
        const high_field = splitter.nextField() orelse return ParseError.InvalidFormat;
        const low_field = splitter.nextField() orelse return ParseError.InvalidFormat;
        const close_field = splitter.nextField() orelse return ParseError.InvalidFormat;
        const volume_field = splitter.nextField() orelse return ParseError.InvalidFormat;

        // Try fast YYYY-MM-DD parsing first (most common format)
        const timestamp = fast.parseDateYYYYMMDD(date_field) catch |err| {
            switch (err) {
                error.InvalidTimestamp => return ParseError.InvalidTimestamp,
                error.DateBeforeEpoch => return ParseError.DateBeforeEpoch,
            }
        };

        // Parse numeric fields using fast parsers
        const open = fast.parseFloat(open_field) catch return ParseError.InvalidNumber;
        const high = fast.parseFloat(high_field) catch return ParseError.InvalidNumber;
        const low = fast.parseFloat(low_field) catch return ParseError.InvalidNumber;
        const close = fast.parseFloat(close_field) catch return ParseError.InvalidNumber;
        const volume = fast.parseInt(volume_field) catch return ParseError.InvalidNumber;

        return .{
            .u64_timestamp = timestamp,
            .f64_open = open,
            .f64_high = high,
            .f64_low = low,
            .f64_close = close,
            .u64_volume = volume,
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────────── Batch Processing with Arena ────────────────────────────────────┐

    /// Parse using arena allocator for better performance
    pub fn parseWithArena(self: Self, data: []const u8, arena: *std.heap.ArenaAllocator) !TimeSeries {
        const arena_allocator = arena.allocator();

        // Use arena for temporary allocations
        var rows = ArrayList(OhlcvRow).init(arena_allocator);

        // Pre-count and allocate
        const line_count = fast.countNewlines(data) + 1;
        const capacity = if (self.b_skip_header and line_count > 0) line_count - 1 else line_count;
        try rows.ensureTotalCapacity(capacity);

        var it = std.mem.splitAny(u8, data, "\r\n");
        var header_skipped = !self.b_skip_header;

        while (it.next()) |line| {
            if (line.len == 0) continue;
            if (!header_skipped) {
                header_skipped = true;
                continue;
            }

            const row = parseLine(line) catch continue;

            if (self.b_validate_data) {
                if (row.f64_open == 0 or row.f64_high == 0 or
                    row.f64_low == 0 or row.f64_close == 0 or row.u64_volume == 0)
                {
                    continue;
                }
            }

            try rows.append(row);
        }

        // Transfer ownership to main allocator
        const final_rows = try self.allocator.alloc(OhlcvRow, rows.items.len);
        @memcpy(final_rows, rows.items);

        return try TimeSeries.fromSlice(self.allocator, final_rows, true);
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
