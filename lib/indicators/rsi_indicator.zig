// ╔══════════════════════════════════════ RSI Indicator ══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const RsiIndicator = struct {
    const Self = @This();

    u32_period: u32 = 14,

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    /// Calculate Relative Strength Index
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() <= self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate initial average gain and loss
        var gains_sum: f64 = 0;
        var losses_sum: f64 = 0;

        var i: usize = 1;
        while (i <= period) : (i += 1) {
            const change = series.arr_rows[i].f64_close - series.arr_rows[i - 1].f64_close;
            if (change > 0) {
                gains_sum += change;
            } else {
                losses_sum += -change;
            }
        }

        var avg_gain = gains_sum / @as(f64, @floatFromInt(period));
        var avg_loss = losses_sum / @as(f64, @floatFromInt(period));

        // Calculate first RSI
        const first_rsi = if (avg_loss == 0) 100.0 else blk: {
            const rs = avg_gain / avg_loss;
            break :blk 100.0 - (100.0 / (1.0 + rs));
        };

        values[0] = first_rsi;
        timestamps[0] = series.arr_rows[period].u64_timestamp;

        // Calculate subsequent RSI values using Wilder's smoothing
        var j: usize = 1;
        while (i < series.len()) : (i += 1) {
            const change = series.arr_rows[i].f64_close - series.arr_rows[i - 1].f64_close;
            const current_gain = if (change > 0) change else 0;
            const current_loss = if (change < 0) -change else 0;

            // Wilder's smoothing method
            avg_gain = (avg_gain * @as(f64, @floatFromInt(period - 1)) + current_gain) / @as(f64, @floatFromInt(period));
            avg_loss = (avg_loss * @as(f64, @floatFromInt(period - 1)) + current_loss) / @as(f64, @floatFromInt(period));

            const rsi = if (avg_loss == 0) 100.0 else blk: {
                const rs = avg_gain / avg_loss;
                break :blk 100.0 - (100.0 / (1.0 + rs));
            };

            values[j] = rsi;
            timestamps[j] = series.arr_rows[i].u64_timestamp;
            j += 1;
        }

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════╝
