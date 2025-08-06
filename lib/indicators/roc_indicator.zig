// ╔════════════════════════════════════════ ROC Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const RocIndicator = struct {
    const Self = @This();

    u32_period: u32 = 14,

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
        DivisionByZero,
    };

    /// Calculate Rate of Change (ROC) as percentage
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() <= self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate ROC for each position
        var i: usize = 0;
        while (i < result_len) : (i += 1) {
            const current_price = series.arr_rows[i + period].f64_close;
            const past_price = series.arr_rows[i].f64_close;

            if (past_price == 0) return Error.DivisionByZero;

            // ROC = ((Current Price - Past Price) / Past Price) * 100
            values[i] = ((current_price - past_price) / past_price) * 100.0;
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