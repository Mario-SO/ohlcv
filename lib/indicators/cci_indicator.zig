// ╔══════════════════════════════════════════ CCI Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const CciIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 20,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────── Calculate Commodity Channel Index ──────────────────────────────┐

    /// CCI = (TP - SMA(TP)) / (0.015 * MeanDeviation)
    /// where TP = (H + L + C) / 3
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period + 1;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Precompute typical prices
        var tp = try allocator.alloc(f64, series.len());
        defer allocator.free(tp);
        for (0..series.len()) |i| {
            const row = series.arr_rows[i];
            tp[i] = (row.f64_high + row.f64_low + row.f64_close) / 3.0;
        }

        // Rolling window for SMA(TP) and Mean Deviation
        var sum_tp: f64 = 0.0;
        for (0..period) |i| sum_tp += tp[i];

        var i: usize = 0;
        while (i < result_len) : (i += 1) {
            const sma_tp = sum_tp / @as(f64, @floatFromInt(period));

            // Mean Absolute Deviation over the window
            var mad: f64 = 0.0;
            var j: usize = 0;
            while (j < period) : (j += 1) {
                mad += @abs(tp[i + j] - sma_tp);
            }
            mad = mad / @as(f64, @floatFromInt(period));

            const denom = 0.015 * mad;
            values[i] = if (denom == 0) 0 else (tp[i + period - 1] - sma_tp) / denom;
            timestamps[i] = series.arr_rows[i + period - 1].u64_timestamp;

            if (i + 1 < result_len) {
                sum_tp -= tp[i];
                sum_tp += tp[i + period];
            }
        }

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════════╝
