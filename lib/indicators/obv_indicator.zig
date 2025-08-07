// ╔══════════════════════════════════════════ OBV Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const ObvIndicator = struct {
    const Self = @This();

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────── Calculate On-Balance Volume ───────────────────────────────────┐

    /// OBV is a cumulative volume measure. If close > prev_close: add volume, if < subtract, else unchanged.
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        _ = self;
        if (series.len() == 0) return Error.InsufficientData;

        var values = try allocator.alloc(f64, series.len());
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, series.len());
        errdefer allocator.free(timestamps);

        var obv: f64 = 0.0;
        var i: usize = 0;
        while (i < series.len()) : (i += 1) {
            if (i == 0) {
                obv = 0.0; // start at zero
            } else {
                const prev_close = series.arr_rows[i - 1].f64_close;
                const close = series.arr_rows[i].f64_close;
                const vol_f64 = @as(f64, @floatFromInt(series.arr_rows[i].u64_volume));

                if (close > prev_close) {
                    obv += vol_f64;
                } else if (close < prev_close) {
                    obv -= vol_f64;
                }
            }
            values[i] = obv;
            timestamps[i] = series.arr_rows[i].u64_timestamp;
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
