// ╔═══════════════════════════════════════ TRIX Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const TrixIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 14,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
        DivisionByZero,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────── Calculate TRIX Indicator ──────────────────────────────────┐

    /// Calculate TRIX (Triple Exponential Average) indicator
    /// TRIX = (EMA3[today] - EMA3[yesterday]) / EMA3[yesterday] × 10000
    /// where EMA3 is the third level exponential moving average
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period * 3) return Error.InsufficientData;

        const period = self.u32_period;
        const multiplier = 2.0 / @as(f64, @floatFromInt(period + 1));

        // ┌─────────────────────────── Calculate First EMA (EMA1) ────────────────────────────┐

        var ema1_values = try allocator.alloc(f64, series.len());
        defer allocator.free(ema1_values);

        // Calculate initial SMA for EMA1
        var sum: f64 = 0;
        for (series.arr_rows[0..period]) |row| {
            sum += row.f64_close;
        }

        var ema1 = sum / @as(f64, @floatFromInt(period));
        ema1_values[period - 1] = ema1;

        // Calculate subsequent EMA1 values
        var i: usize = period;
        while (i < series.len()) : (i += 1) {
            ema1 = (series.arr_rows[i].f64_close - ema1) * multiplier + ema1;
            ema1_values[i] = ema1;
        }

        // └───────────────────────────────────────────────────────────────────────────────────┘

        // ┌─────────────────────────── Calculate Second EMA (EMA2) ───────────────────────────┐

        const ema2_start = period * 2 - 1;
        if (series.len() <= ema2_start) return Error.InsufficientData;

        var ema2_values = try allocator.alloc(f64, series.len());
        defer allocator.free(ema2_values);

        // Calculate initial SMA for EMA2 using EMA1 values
        sum = 0;
        for (ema1_values[period - 1..ema2_start]) |value| {
            sum += value;
        }

        var ema2 = sum / @as(f64, @floatFromInt(period));
        ema2_values[ema2_start] = ema2;

        // Calculate subsequent EMA2 values
        i = ema2_start + 1;
        while (i < series.len()) : (i += 1) {
            ema2 = (ema1_values[i] - ema2) * multiplier + ema2;
            ema2_values[i] = ema2;
        }

        // └───────────────────────────────────────────────────────────────────────────────────┘

        // ┌─────────────────────────── Calculate Third EMA (EMA3) ────────────────────────────┐

        const ema3_start = period * 3 - 1;
        if (series.len() <= ema3_start) return Error.InsufficientData;

        var ema3_values = try allocator.alloc(f64, series.len());
        defer allocator.free(ema3_values);

        // Calculate initial SMA for EMA3 using EMA2 values
        sum = 0;
        for (ema2_values[ema2_start..ema3_start]) |value| {
            sum += value;
        }

        var ema3 = sum / @as(f64, @floatFromInt(period));
        ema3_values[ema3_start] = ema3;

        // Calculate subsequent EMA3 values
        i = ema3_start + 1;
        while (i < series.len()) : (i += 1) {
            ema3 = (ema2_values[i] - ema3) * multiplier + ema3;
            ema3_values[i] = ema3;
        }

        // └───────────────────────────────────────────────────────────────────────────────────┘

        // ┌────────────────────────── Calculate TRIX Rate of Change ──────────────────────────┐

        // TRIX needs at least one more period for rate of change calculation
        const trix_start = ema3_start + 1;
        if (series.len() <= trix_start) return Error.InsufficientData;

        const result_len = series.len() - trix_start;
        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate TRIX for each position
        i = 0;
        while (i < result_len) : (i += 1) {
            const current_ema3 = ema3_values[trix_start + i];
            const previous_ema3 = ema3_values[trix_start + i - 1];

            if (previous_ema3 == 0) return Error.DivisionByZero;

            // TRIX = (EMA3[today] - EMA3[yesterday]) / EMA3[yesterday] × 10000
            values[i] = ((current_ema3 - previous_ema3) / previous_ema3) * 10000.0;
            timestamps[i] = series.arr_rows[trix_start + i].u64_timestamp;
        }

        // └───────────────────────────────────────────────────────────────────────────────────┘

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝