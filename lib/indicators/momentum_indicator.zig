// ╔══════════════════════════════════════ Momentum Indicator ═════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const MomentumIndicator = struct {
    const Self = @This();

    u32_period: u32 = 10,

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    /// Calculate Momentum (difference between current price and price n periods ago)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() <= self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate Momentum for each position
        var i: usize = 0;
        while (i < result_len) : (i += 1) {
            const current_price = series.arr_rows[i + period].f64_close;
            const past_price = series.arr_rows[i].f64_close;

            // Momentum = Current Price - Past Price
            values[i] = current_price - past_price;
            timestamps[i] = series.arr_rows[i + period].u64_timestamp;
        }

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝