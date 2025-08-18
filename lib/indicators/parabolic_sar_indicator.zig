// ╔══════════════════════════════════════ Parabolic SAR Indicator ═══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const ParabolicSarIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    f64_initial_af: f64 = 0.02,      // Initial acceleration factor
    f64_af_increment: f64 = 0.02,    // Acceleration factor increment
    f64_max_af: f64 = 0.20,          // Maximum acceleration factor

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────── Calculate Parabolic SAR (Stop and Reverse) ────────────────────────────┐

    /// Calculate Parabolic SAR (Stop and Reverse)
    /// The Parabolic SAR is a trend-following indicator that provides trailing stop levels.
    /// It was developed by J. Welles Wilder Jr. and helps identify potential reversal points.
    /// 
    /// Algorithm:
    /// - Rising SAR = Prior SAR + Prior AF × (Prior EP - Prior SAR)
    /// - Falling SAR = Prior SAR - Prior AF × (Prior SAR - Prior EP)
    /// - EP (Extreme Point) is the highest high in uptrend or lowest low in downtrend
    /// - AF (Acceleration Factor) starts at initial_af and increases by af_increment
    ///   each time a new extreme point is reached, up to max_af
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.f64_initial_af <= 0 or self.f64_af_increment <= 0 or self.f64_max_af <= 0) {
            return Error.InvalidParameters;
        }
        if (self.f64_initial_af > self.f64_max_af) {
            return Error.InvalidParameters;
        }
        if (series.len() < 2) {
            return Error.InsufficientData;
        }

        const data_len = series.len();
        
        var values = try allocator.alloc(f64, data_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, data_len);
        errdefer allocator.free(timestamps);

        // Initialize variables for Parabolic SAR calculation
        var is_uptrend: bool = undefined;
        var current_sar: f64 = undefined;
        var extreme_point: f64 = undefined;
        var acceleration_factor: f64 = self.f64_initial_af;

        // Determine initial trend direction based on first two periods
        // If second period's high > first period's high, assume uptrend, otherwise downtrend
        if (series.arr_rows[1].f64_high > series.arr_rows[0].f64_high) {
            is_uptrend = false; // Start with downtrend SAR (above price)
            current_sar = series.arr_rows[0].f64_high;
            extreme_point = series.arr_rows[1].f64_low;
        } else {
            is_uptrend = true; // Start with uptrend SAR (below price)
            current_sar = series.arr_rows[0].f64_low;
            extreme_point = series.arr_rows[1].f64_high;
        }

        // Set first SAR value and timestamp
        values[0] = current_sar;
        timestamps[0] = series.arr_rows[0].u64_timestamp;

        // Calculate SAR for each subsequent period
        var i: usize = 1;
        while (i < data_len) : (i += 1) {
            const current_row = series.arr_rows[i];
            var next_sar: f64 = undefined;
            var new_extreme_point = false;

            if (is_uptrend) {
                // Uptrend: SAR is below price
                // SAR = Prior SAR + AF × (EP - Prior SAR)
                next_sar = current_sar + acceleration_factor * (extreme_point - current_sar);

                // Check for new extreme point (higher high)
                if (current_row.f64_high > extreme_point) {
                    extreme_point = current_row.f64_high;
                    new_extreme_point = true;
                }

                // SAR cannot be above the current or previous period's low
                const min_low = @min(current_row.f64_low, 
                    if (i > 0) series.arr_rows[i - 1].f64_low else current_row.f64_low);
                if (next_sar > min_low) {
                    next_sar = min_low;
                }

                // Check for trend reversal (SAR touches or exceeds price)
                if (next_sar >= current_row.f64_low) {
                    // Trend reversal to downtrend
                    is_uptrend = false;
                    next_sar = extreme_point; // SAR becomes the previous EP
                    extreme_point = current_row.f64_low; // New EP is current low
                    acceleration_factor = self.f64_initial_af; // Reset AF
                }
            } else {
                // Downtrend: SAR is above price
                // SAR = Prior SAR - AF × (Prior SAR - EP)
                next_sar = current_sar - acceleration_factor * (current_sar - extreme_point);

                // Check for new extreme point (lower low)
                if (current_row.f64_low < extreme_point) {
                    extreme_point = current_row.f64_low;
                    new_extreme_point = true;
                }

                // SAR cannot be below the current or previous period's high
                const max_high = @max(current_row.f64_high,
                    if (i > 0) series.arr_rows[i - 1].f64_high else current_row.f64_high);
                if (next_sar < max_high) {
                    next_sar = max_high;
                }

                // Check for trend reversal (SAR touches or falls below price)
                if (next_sar <= current_row.f64_high) {
                    // Trend reversal to uptrend
                    is_uptrend = true;
                    next_sar = extreme_point; // SAR becomes the previous EP
                    extreme_point = current_row.f64_high; // New EP is current high
                    acceleration_factor = self.f64_initial_af; // Reset AF
                }
            }

            // Update acceleration factor if new extreme point was found (but not during reversal)
            if (new_extreme_point and acceleration_factor < self.f64_max_af) {
                acceleration_factor = @min(acceleration_factor + self.f64_af_increment, self.f64_max_af);
            }

            // Store the calculated SAR value and timestamp
            values[i] = next_sar;
            timestamps[i] = current_row.u64_timestamp;
            current_sar = next_sar;
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