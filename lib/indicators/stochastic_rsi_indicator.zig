// ╔════════════════════════════════════ Stochastic RSI Indicator ═════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const StochasticRsiIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_rsi_period: u32 = 14,        // Period for RSI calculation
    u32_stochastic_period: u32 = 14, // Period for stochastic calculation on RSI values

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Calculate Stochastic RSI Indicator ────────────────────────────────┐

    /// Calculate Stochastic RSI - applies stochastic formula to RSI values
    /// Returns values normalized between 0 and 1
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_rsi_period == 0 or self.u32_stochastic_period == 0) {
            return Error.InvalidParameters;
        }

        const min_data_needed = self.u32_rsi_period + self.u32_stochastic_period;
        if (series.len() < min_data_needed) return Error.InsufficientData;

        // Step 1: Calculate RSI values
        var rsi_values = try calculateRsi(series, self.u32_rsi_period, allocator);
        defer allocator.free(rsi_values);

        // Step 2: Apply stochastic formula to RSI values
        const result_len = rsi_values.len - self.u32_stochastic_period + 1;
        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        for (0..result_len) |i| {
            const window_start = i;
            const window_end = i + self.u32_stochastic_period;

            // Find highest and lowest RSI values in the stochastic period
            var rsi_high = rsi_values[window_start];
            var rsi_low = rsi_values[window_start];

            for (rsi_values[window_start..window_end]) |rsi_val| {
                if (rsi_val > rsi_high) rsi_high = rsi_val;
                if (rsi_val < rsi_low) rsi_low = rsi_val;
            }

            // Calculate Stochastic RSI
            const current_rsi = rsi_values[window_end - 1];
            const rsi_range = rsi_high - rsi_low;

            // Normalize to 0-1 range (instead of 0-100 like regular stochastic)
            values[i] = if (rsi_range == 0) 0.5 else (current_rsi - rsi_low) / rsi_range;

            // Timestamp corresponds to the end of the stochastic period
            const series_index = self.u32_rsi_period + i + self.u32_stochastic_period - 1;
            timestamps[i] = series.arr_rows[series_index].u64_timestamp;
        }

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────── Helper Functions ─────────────────────────────────────────┐

    /// Calculate RSI values for the given series and period
    fn calculateRsi(series: TimeSeries, period: u32, allocator: Allocator) Error![]f64 {
        if (series.len() <= period) return Error.InsufficientData;

        const result_len = series.len() - period;
        var rsi_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(rsi_values);

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

        rsi_values[0] = first_rsi;

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

            rsi_values[j] = rsi;
            j += 1;
        }

        return rsi_values;
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝