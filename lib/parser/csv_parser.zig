// ╔═════════════════════════════════════════ CSV Parser ══════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const OhlcvRow = @import("../types/ohlcv_row.zig").OhlcvRow;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const date = @import("../date.zig");

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

pub const CsvParser = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    allocator: Allocator,
    b_skip_header: bool = true,
    b_validate_data: bool = true,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────── Parse CSV data into TimeSeries ────────────────────────────────┐

    /// Parse CSV data into TimeSeries
    pub fn parse(self: Self, data: []const u8) !TimeSeries {
        var rows = std.ArrayList(OhlcvRow).init(self.allocator);
        errdefer rows.deinit();

        // Exact pre-allocation based on line count (minus optional header)
        const total_lines = std.mem.count(u8, data, "\n") + 1; // rough for last line w/o newline
        const capacity_hint = if (self.b_skip_header and total_lines > 0) total_lines - 1 else total_lines;
        try rows.ensureTotalCapacity(capacity_hint);

        var it = std.mem.splitAny(u8, data, "\r\n");
        var header_skipped = !self.b_skip_header;
        while (it.next()) |line| {
            if (line.len == 0) continue;
            if (!header_skipped) {
                header_skipped = true;
                continue;
            }

            const row = parseLineFast(line) catch |err| {
                switch (err) {
                    ParseError.DateBeforeEpoch => continue,
                    ParseError.InvalidFormat => continue,
                    ParseError.InvalidTimestamp => continue,
                    ParseError.InvalidNumber => continue,
                    else => return err,
                }
            };

            if (self.b_validate_data) {
                if (row.f64_open == 0 or row.f64_high == 0 or row.f64_low == 0 or row.f64_close == 0 or row.u64_volume == 0) {
                    continue;
                }
            }
            try rows.append(row);
        }

        const owned_rows = try rows.toOwnedSlice();
        return try TimeSeries.fromSlice(self.allocator, owned_rows, true);
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────── Parse a single CSV line ───────────────────────────────────┐

    /// Parse a single CSV line (no quotes). Requires at least 6 columns; extra columns are ignored.
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
