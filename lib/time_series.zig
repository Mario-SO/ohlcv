// ╔═════════════════════════════════════════ Time Series ═════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const OhlcvRow = @import("types/ohlcv_row.zig").OhlcvRow;

/// Efficient container for time series data with zero-copy operations where possible
pub const TimeSeries = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    arr_rows: []OhlcvRow,
    allocator: Allocator,
    b_owns_memory: bool,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────── Initialization ────────────────────────────────────────┐

    /// Initialize an empty time series
    pub fn init(allocator: Allocator) Self {
        return .{
            .arr_rows = &[_]OhlcvRow{},
            .allocator = allocator,
            .b_owns_memory = false,
        };
    }

    /// Create time series from existing data (takes ownership if specified)
    pub fn fromSlice(allocator: Allocator, rows: []OhlcvRow, owns_memory: bool) !Self {
        if (owns_memory) {
            return .{
                .arr_rows = rows,
                .allocator = allocator,
                .b_owns_memory = true,
            };
        } else {
            const owned_rows = try allocator.dupe(OhlcvRow, rows);
            return .{
                .arr_rows = owned_rows,
                .allocator = allocator,
                .b_owns_memory = true,
            };
        }
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────────────────── Memory Management ──────────────────────────────────────┐

    /// Clean up memory if owned
    pub fn deinit(self: Self) void {
        if (self.b_owns_memory and self.arr_rows.len > 0) {
            self.allocator.free(self.arr_rows);
        }
    }

    /// Get number of rows
    pub fn len(self: Self) usize {
        return self.arr_rows.len;
    }

    /// Check if empty
    pub fn isEmpty(self: Self) bool {
        return self.arr_rows.len == 0;
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────────────────── Data Manipulation ──────────────────────────────────────┐

    /// Create a slice by timestamp range (zero-copy view)
    pub fn sliceByTime(self: Self, u64_from: u64, u64_to: u64) !Self {
        var start_idx: ?usize = null;
        var end_idx: ?usize = null;

        // Binary search for efficiency on sorted data
        for (self.arr_rows, 0..) |row, i| {
            if (start_idx == null and row.u64_timestamp >= u64_from) {
                start_idx = i;
            }
            if (row.u64_timestamp > u64_to) {
                end_idx = i;
                break;
            }
        }

        if (start_idx == null) {
            return Self.init(self.allocator);
        }

        const actual_end = end_idx orelse self.arr_rows.len;
        return .{
            .arr_rows = self.arr_rows[start_idx.?..actual_end],
            .allocator = self.allocator,
            .b_owns_memory = false, // View into parent data
        };
    }

    /// Filter rows based on predicate (allocates new array)
    pub fn filter(self: Self, comptime predicate: fn (row: OhlcvRow) bool) !Self {
        var filtered = std.ArrayList(OhlcvRow).init(self.allocator);
        errdefer filtered.deinit();

        for (self.arr_rows) |row| {
            if (predicate(row)) {
                try filtered.append(row);
            }
        }

        return .{
            .arr_rows = try filtered.toOwnedSlice(),
            .allocator = self.allocator,
            .b_owns_memory = true,
        };
    }

    /// Sort by timestamp in-place
    pub fn sortByTime(self: *Self) void {
        std.sort.insertion(OhlcvRow, self.arr_rows, {}, struct {
            fn lessThan(_: void, a: OhlcvRow, b: OhlcvRow) bool {
                return a.u64_timestamp < b.u64_timestamp;
            }
        }.lessThan);
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────────────────────── Iterator ───────────────────────────────────────────┐

    /// Get iterator for efficient traversal
    pub fn iterator(self: Self) Iterator {
        return .{
            .arr_rows = self.arr_rows,
            .u32_index = 0,
        };
    }

    pub const Iterator = struct {
        arr_rows: []const OhlcvRow,
        u32_index: u32,

        pub fn next(self: *Iterator) ?OhlcvRow {
            if (self.u32_index >= self.arr_rows.len) return null;
            const row = self.arr_rows[self.u32_index];
            self.u32_index += 1;
            return row;
        }

        pub fn peek(self: *const Iterator) ?OhlcvRow {
            if (self.u32_index >= self.arr_rows.len) return null;
            return self.arr_rows[self.u32_index];
        }

        pub fn skip(self: *Iterator, n: u32) void {
            self.u32_index = @min(self.u32_index + n, @as(u32, @intCast(self.arr_rows.len)));
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────── Data Extraction ───────────────────────────────────────┐

    /// Map operation for transforming data
    pub fn map(self: Self, comptime T: type, comptime mapFn: fn (row: OhlcvRow) T, allocator: Allocator) ![]T {
        const result = try allocator.alloc(T, self.arr_rows.len);
        for (self.arr_rows, 0..) |row, i| {
            result[i] = mapFn(row);
        }
        return result;
    }

    /// Extract closing prices as slice
    pub fn closePrices(self: Self, allocator: Allocator) ![]f64 {
        return self.map(f64, struct {
            fn getClose(row: OhlcvRow) f64 {
                return row.f64_close;
            }
        }.getClose, allocator);
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
