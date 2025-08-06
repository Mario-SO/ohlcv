// ╔════════════════════════════════════════ WMA Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const WmaIndicator = struct {
    const Self = @This();

    u32_period: u32,

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    /// Calculate Weighted Moving Average
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period + 1;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate denominator for weights (1+2+3+...+period)
        const weight_sum: f64 = @as(f64, @floatFromInt(period * (period + 1) / 2));

        // Calculate WMA for each position
        var i: usize = 0;
        while (i < result_len) : (i += 1) {
            var weighted_sum: f64 = 0;

            // Apply weights (most recent price gets highest weight)
            var j: usize = 0;
            while (j < period) : (j += 1) {
                const weight = @as(f64, @floatFromInt(j + 1));
                weighted_sum += series.arr_rows[i + j].f64_close * weight;
            }

            values[i] = weighted_sum / weight_sum;
            timestamps[i] = series.arr_rows[i + period - 1].u64_timestamp;
        }

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝