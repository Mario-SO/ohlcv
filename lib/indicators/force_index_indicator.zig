// ╔══════════════════════════════════ Force Index Indicator ══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const ForceIndexIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 13,
    f64_smoothing: f64 = 2.0,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────── Calculate Force Index ─────────────────────────────────────┐

    /// Calculate Force Index (combines price change and volume)
    /// Force Index = (Close - Previous Close) × Volume
    /// Then smoothed with EMA
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period + 1) return Error.InsufficientData; // Need extra period for price change

        const period = self.u32_period;
        const multiplier = self.f64_smoothing / @as(f64, @floatFromInt(period + 1));

        // Calculate raw Force Index values first
        var raw_force_values = try allocator.alloc(f64, series.len() - 1);
        defer allocator.free(raw_force_values);

        var i: usize = 1;
        while (i < series.len()) : (i += 1) {
            const current_row = series.arr_rows[i];
            const previous_row = series.arr_rows[i - 1];
            const price_change = current_row.f64_close - previous_row.f64_close;
            const volume = @as(f64, @floatFromInt(current_row.u64_volume));
            raw_force_values[i - 1] = price_change * volume;
        }

        // Calculate EMA of Force Index values
        const result_len = raw_force_values.len - period + 1;
        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate initial SMA as starting point for EMA
        var sum: f64 = 0;
        for (raw_force_values[0..period]) |raw_value| {
            sum += raw_value;
        }

        // First EMA value is the SMA
        var ema = sum / @as(f64, @floatFromInt(period));
        values[0] = ema;
        timestamps[0] = series.arr_rows[period].u64_timestamp; // Align with data that has the period offset

        // Calculate subsequent EMA values
        var j: usize = 1;
        var raw_index = period;
        while (raw_index < raw_force_values.len) : (raw_index += 1) {
            ema = (raw_force_values[raw_index] - ema) * multiplier + ema;
            values[j] = ema;
            timestamps[j] = series.arr_rows[raw_index + 1].u64_timestamp; // +1 because raw_force_values is offset by 1
            j += 1;
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