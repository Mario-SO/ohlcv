// ╔════════════════════════════════════════ SMA Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const SmaIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────── Calculate Simple Moving Average ───────────────────────────────┐

    /// Calculate Simple Moving Average
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period + 1;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate first SMA
        var sum: f64 = 0;
        for (series.arr_rows[0..period]) |row| {
            sum += row.f64_close;
        }

        values[0] = sum / @as(f64, @floatFromInt(period));
        timestamps[0] = series.arr_rows[period - 1].u64_timestamp;

        // Calculate rolling SMAs efficiently
        var i: usize = 1;
        while (i < result_len) : (i += 1) {
            sum -= series.arr_rows[i - 1].f64_close;
            sum += series.arr_rows[i + period - 1].f64_close;
            values[i] = sum / @as(f64, @floatFromInt(period));
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
