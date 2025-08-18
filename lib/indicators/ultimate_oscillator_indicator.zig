// ╔══════════════════════════════════ Ultimate Oscillator Indicator ═══════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const UltimateOscillatorIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period1: u32 = 7,
    u32_period2: u32 = 14,
    u32_period3: u32 = 28,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────── Calculate Ultimate Oscillator ────────────────────────────────┐

    /// Calculate Ultimate Oscillator
    /// The Ultimate Oscillator combines short, medium, and long-term price action:
    /// BP = Close - Min(Low, Prior Close)
    /// TR = Max(High, Prior Close) - Min(Low, Prior Close) 
    /// UO = 100 * ((4*Avg7 + 2*Avg14 + Avg28) / 7)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period1 == 0 or self.u32_period2 == 0 or self.u32_period3 == 0) return Error.InvalidParameters;
        if (self.u32_period1 >= self.u32_period2 or self.u32_period2 >= self.u32_period3) return Error.InvalidParameters;
        
        const max_period = self.u32_period3;
        if (series.len() <= max_period) return Error.InsufficientData;

        const period1 = self.u32_period1;
        const period2 = self.u32_period2;
        const result_len = series.len() - max_period;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate Buying Pressure and True Range for each bar (starting from index 1)
        var buying_pressure = try allocator.alloc(f64, series.len() - 1);
        defer allocator.free(buying_pressure);

        var true_range = try allocator.alloc(f64, series.len() - 1);
        defer allocator.free(true_range);

        for (1..series.len()) |i| {
            const current = series.arr_rows[i];
            const previous = series.arr_rows[i - 1];

            // Buying Pressure = Close - Min(Low, Prior Close)
            const min_low_prev_close = @min(current.f64_low, previous.f64_close);
            buying_pressure[i - 1] = current.f64_close - min_low_prev_close;

            // True Range = Max(High, Prior Close) - Min(Low, Prior Close)
            const max_high_prev_close = @max(current.f64_high, previous.f64_close);
            true_range[i - 1] = max_high_prev_close - min_low_prev_close;
        }

        // Calculate Ultimate Oscillator values
        for (0..result_len) |i| {
            const start_idx = i;
            
            // Calculate averages for each period
            var bp_sum1: f64 = 0;
            var tr_sum1: f64 = 0;
            var bp_sum2: f64 = 0;
            var tr_sum2: f64 = 0;
            var bp_sum3: f64 = 0;
            var tr_sum3: f64 = 0;

            // Period 1 (shortest)
            const start1 = start_idx + max_period - period1;
            for (start1..start_idx + max_period) |j| {
                bp_sum1 += buying_pressure[j];
                tr_sum1 += true_range[j];
            }

            // Period 2 (medium)  
            const start2 = start_idx + max_period - period2;
            for (start2..start_idx + max_period) |j| {
                bp_sum2 += buying_pressure[j];
                tr_sum2 += true_range[j];
            }

            // Period 3 (longest)
            const start3 = start_idx;
            for (start3..start_idx + max_period) |j| {
                bp_sum3 += buying_pressure[j];
                tr_sum3 += true_range[j];
            }

            // Calculate averages (avoid division by zero)
            const avg1 = if (tr_sum1 == 0) 0 else bp_sum1 / tr_sum1;
            const avg2 = if (tr_sum2 == 0) 0 else bp_sum2 / tr_sum2;
            const avg3 = if (tr_sum3 == 0) 0 else bp_sum3 / tr_sum3;

            // Ultimate Oscillator = 100 * ((4*Avg1 + 2*Avg2 + Avg3) / 7)
            const ultimate_oscillator = 100.0 * ((4.0 * avg1 + 2.0 * avg2 + avg3) / 7.0);

            values[i] = ultimate_oscillator;
            timestamps[i] = series.arr_rows[i + max_period].u64_timestamp;
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