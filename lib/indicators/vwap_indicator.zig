// ╔══════════════════════════════════════════ VWAP Indicator ═══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const VwapIndicator = struct {
    const Self = @This();

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        OutOfMemory,
        DivisionByZero,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────────── Calculate Volume Weighted Average Price ─────────────────────────┐

    /// Calculate cumulative Volume Weighted Average Price using typical price ((H+L+C)/3)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        _ = self;

        if (series.len() == 0) return Error.InsufficientData;

        var values = try allocator.alloc(f64, series.len());
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, series.len());
        errdefer allocator.free(timestamps);

        var cumulative_pv: f64 = 0.0;
        var cumulative_vol: f64 = 0.0;

        var i: usize = 0;
        while (i < series.len()) : (i += 1) {
            const row = series.arr_rows[i];
            const typical_price = (row.f64_high + row.f64_low + row.f64_close) / 3.0;
            const vol_f64 = @as(f64, @floatFromInt(row.u64_volume));

            cumulative_pv += typical_price * vol_f64;
            cumulative_vol += vol_f64;

            if (cumulative_vol == 0) return Error.DivisionByZero;

            values[i] = cumulative_pv / cumulative_vol;
            timestamps[i] = row.u64_timestamp;
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
