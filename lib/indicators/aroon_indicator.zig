// ╔═════════════════════════════════════════ Aroon Indicator ═══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const AroonIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 25,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────────── Result ────────────────────────────────────────────┐

    pub const AroonResult = struct {
        aroon_up: IndicatorResult,
        aroon_down: IndicatorResult,

        pub fn deinit(self: *AroonResult) void {
            self.aroon_up.deinit();
            self.aroon_down.deinit();
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Calculate Aroon ──────────────────────────────────┐

    /// Aroon Up = ((period - periods_since_high) / period) * 100
    /// Aroon Down = ((period - periods_since_low) / period) * 100
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!AroonResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period + 1;

        var up_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(up_values);

        var down_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(down_values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        var i: usize = 0;
        while (i < result_len) : (i += 1) {
            var highest_high = series.arr_rows[i].f64_high;
            var idx_high: usize = 0;
            var lowest_low = series.arr_rows[i].f64_low;
            var idx_low: usize = 0;

            var j: usize = 0;
            while (j < period) : (j += 1) {
                const row = series.arr_rows[i + j];
                if (row.f64_high >= highest_high) {
                    highest_high = row.f64_high;
                    idx_high = j;
                }
                if (row.f64_low <= lowest_low) {
                    lowest_low = row.f64_low;
                    idx_low = j;
                }
            }

            const periods_since_high = (period - 1) - idx_high;
            const periods_since_low = (period - 1) - idx_low;

            up_values[i] = (@as(f64, @floatFromInt(period - periods_since_high)) / @as(f64, @floatFromInt(period))) * 100.0;
            down_values[i] = (@as(f64, @floatFromInt(period - periods_since_low)) / @as(f64, @floatFromInt(period))) * 100.0;
            timestamps[i] = series.arr_rows[i + period - 1].u64_timestamp;
        }

        const up_ts = try allocator.dupe(u64, timestamps);
        const down_ts = try allocator.dupe(u64, timestamps);
        allocator.free(timestamps);

        return AroonResult{
            .aroon_up = .{ .arr_values = up_values, .arr_timestamps = up_ts, .allocator = allocator },
            .aroon_down = .{ .arr_values = down_values, .arr_timestamps = down_ts, .allocator = allocator },
        };
    }
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════════╝
