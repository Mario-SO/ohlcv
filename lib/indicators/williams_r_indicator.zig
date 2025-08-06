// ╔══════════════════════════════════════ Williams %R Indicator ══════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const WilliamsRIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 14,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────── Calculate Williams %R ────────────────────────────────────┐

    /// Calculate Williams %R
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period + 1;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate Williams %R for each position
        var i: usize = 0;
        while (i < result_len) : (i += 1) {
            // Find highest high and lowest low in the period
            var highest_high = series.arr_rows[i].f64_high;
            var lowest_low = series.arr_rows[i].f64_low;

            var j: usize = i;
            while (j < i + period) : (j += 1) {
                if (series.arr_rows[j].f64_high > highest_high) {
                    highest_high = series.arr_rows[j].f64_high;
                }
                if (series.arr_rows[j].f64_low < lowest_low) {
                    lowest_low = series.arr_rows[j].f64_low;
                }
            }

            const current_close = series.arr_rows[i + period - 1].f64_close;
            const range = highest_high - lowest_low;

            // Williams %R = ((Highest High - Close) / (Highest High - Lowest Low)) * -100
            if (range == 0) {
                values[i] = 0;
            } else {
                values[i] = ((highest_high - current_close) / range) * -100.0;
            }

            timestamps[i] = series.arr_rows[i + period - 1].u64_timestamp;
        }

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
