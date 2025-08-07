// ╔═══════════════════════════════════ Bollinger Bands Indicator ══════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const BollingerBandsIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 20,
    f64_std_dev_multiplier: f64 = 2.0,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────────── Result ────────────────────────────────────────────┐

    pub const BollingerBandsResult = struct {
        upper_band: IndicatorResult,
        middle_band: IndicatorResult, // SMA
        lower_band: IndicatorResult,

        pub fn deinit(self: *BollingerBandsResult) void {
            self.upper_band.deinit();
            self.middle_band.deinit();
            self.lower_band.deinit();
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌───────────────── Calculate Bollinger Bands using SMA and standard deviation ──────────────────┐

    /// Calculate Bollinger Bands (Upper, Middle, Lower)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!BollingerBandsResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period + 1;

        // Allocate arrays for all three bands
        var upper_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(upper_values);

        var middle_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(middle_values);

        var lower_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(lower_values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate for each window
        for (0..result_len) |i| {
            const window_start = i;
            const window_end = i + period;

            // Calculate SMA (middle band)
            var sum: f64 = 0;
            for (series.arr_rows[window_start..window_end]) |row| {
                sum += row.f64_close;
            }
            const sma = sum / @as(f64, @floatFromInt(period));
            middle_values[i] = sma;

            // Calculate standard deviation
            var variance: f64 = 0;
            for (series.arr_rows[window_start..window_end]) |row| {
                const diff = row.f64_close - sma;
                variance += diff * diff;
            }
            const std_dev = @sqrt(variance / @as(f64, @floatFromInt(period)));

            // Calculate bands
            const band_offset = std_dev * self.f64_std_dev_multiplier;
            upper_values[i] = sma + band_offset;
            lower_values[i] = sma - band_offset;

            timestamps[i] = series.arr_rows[window_end - 1].u64_timestamp;
        }

        // Create separate timestamp arrays for each band
        const upper_timestamps = try allocator.dupe(u64, timestamps);
        const middle_timestamps = try allocator.dupe(u64, timestamps);
        const lower_timestamps = try allocator.dupe(u64, timestamps);

        allocator.free(timestamps);

        return BollingerBandsResult{
            .upper_band = .{
                .arr_values = upper_values,
                .arr_timestamps = upper_timestamps,
                .allocator = allocator,
            },
            .middle_band = .{
                .arr_values = middle_values,
                .arr_timestamps = middle_timestamps,
                .allocator = allocator,
            },
            .lower_band = .{
                .arr_values = lower_values,
                .arr_timestamps = lower_timestamps,
                .allocator = allocator,
            },
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
