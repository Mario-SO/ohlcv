// ╔═════════════════════════════════════════ ATR Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const AtrIndicator = struct {
    const Self = @This();

    u32_period: u32 = 14,

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    /// Calculate Average True Range
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() <= self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        
        // Calculate True Range for each bar (starting from index 1)
        var true_ranges = try allocator.alloc(f64, series.len() - 1);
        defer allocator.free(true_ranges);

        for (1..series.len()) |i| {
            const current = series.arr_rows[i];
            const previous = series.arr_rows[i - 1];
            
            const high_low = current.f64_high - current.f64_low;
            const high_close_prev = @abs(current.f64_high - previous.f64_close);
            const low_close_prev = @abs(current.f64_low - previous.f64_close);
            
            true_ranges[i - 1] = @max(high_low, @max(high_close_prev, low_close_prev));
        }

        const result_len = true_ranges.len - period + 1;
        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate first ATR as simple average
        var sum: f64 = 0;
        for (true_ranges[0..period]) |tr| {
            sum += tr;
        }
        var atr = sum / @as(f64, @floatFromInt(period));
        values[0] = atr;
        timestamps[0] = series.arr_rows[period].u64_timestamp;

        // Calculate subsequent ATR values using Wilder's smoothing
        // ATR = (Previous ATR * (n-1) + Current TR) / n
        var i: usize = 1;
        while (i < result_len) : (i += 1) {
            const current_tr = true_ranges[period - 1 + i];
            atr = (atr * @as(f64, @floatFromInt(period - 1)) + current_tr) / @as(f64, @floatFromInt(period));
            values[i] = atr;
            timestamps[i] = series.arr_rows[period + i].u64_timestamp;
        }

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝