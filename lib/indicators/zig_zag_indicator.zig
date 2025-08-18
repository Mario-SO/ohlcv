// ╔═══════════════════════════════════════ Zig Zag Indicator ═════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const ZigZagIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    f64_threshold: f64 = 5.0, // Percentage threshold for price reversals

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────── Zig Zag Calculation ───────────────────────────────────┐

    /// Calculate Zig Zag indicator
    /// The Zig Zag indicator filters out price movements smaller than the specified threshold
    /// and identifies significant peaks and troughs. Returns NaN for most values except at
    /// reversal points where it returns the high/low price that forms the reversal.
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.f64_threshold <= 0.0 or self.f64_threshold >= 100.0) return Error.InvalidParameters;
        if (series.len() < 3) return Error.InsufficientData;

        const threshold_decimal = self.f64_threshold / 100.0;
        const len = series.len();

        var values = try allocator.alloc(f64, len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, len);
        errdefer allocator.free(timestamps);

        // Initialize all values to NaN
        for (values) |*value| {
            value.* = std.math.nan(f64);
        }

        // Copy timestamps
        for (series.arr_rows, 0..) |row, i| {
            timestamps[i] = row.u64_timestamp;
        }

        if (len == 0) {
            return .{
                .arr_values = values,
                .arr_timestamps = timestamps,
                .allocator = allocator,
            };
        }

        // Track state for zig zag calculation
        var trend: enum { up, down, unknown } = .unknown;
        var last_pivot_index: usize = 0;
        var last_pivot_price: f64 = 0.0;
        var current_extreme_index: usize = 0;
        var current_extreme_price: f64 = 0.0;

        // Start with the first bar
        last_pivot_price = series.arr_rows[0].f64_close;
        current_extreme_price = series.arr_rows[0].f64_close;

        var i: usize = 1;
        while (i < len) : (i += 1) {
            const high = series.arr_rows[i].f64_high;
            const low = series.arr_rows[i].f64_low;

            if (trend == .unknown) {
                // Establish initial trend direction
                if (high > current_extreme_price) {
                    current_extreme_price = high;
                    current_extreme_index = i;
                }
                if (low < current_extreme_price) {
                    current_extreme_price = low;
                    current_extreme_index = i;
                }

                // Check if we have enough movement to establish trend
                const upward_move = (high - last_pivot_price) / last_pivot_price;
                const downward_move = (last_pivot_price - low) / last_pivot_price;

                if (upward_move >= threshold_decimal) {
                    trend = .up;
                    current_extreme_price = high;
                    current_extreme_index = i;
                } else if (downward_move >= threshold_decimal) {
                    trend = .down;
                    current_extreme_price = low;
                    current_extreme_index = i;
                }
            } else if (trend == .up) {
                // In uptrend, look for new highs or reversal
                if (high > current_extreme_price) {
                    current_extreme_price = high;
                    current_extreme_index = i;
                } else {
                    // Check for reversal
                    const retracement = (current_extreme_price - low) / current_extreme_price;
                    if (retracement >= threshold_decimal) {
                        // Confirmed reversal - mark the previous high
                        values[current_extreme_index] = current_extreme_price;
                        
                        // Switch to downtrend
                        trend = .down;
                        last_pivot_index = current_extreme_index;
                        last_pivot_price = current_extreme_price;
                        current_extreme_price = low;
                        current_extreme_index = i;
                    }
                }
            } else if (trend == .down) {
                // In downtrend, look for new lows or reversal
                if (low < current_extreme_price) {
                    current_extreme_price = low;
                    current_extreme_index = i;
                } else {
                    // Check for reversal
                    const retracement = (high - current_extreme_price) / current_extreme_price;
                    if (retracement >= threshold_decimal) {
                        // Confirmed reversal - mark the previous low
                        values[current_extreme_index] = current_extreme_price;
                        
                        // Switch to uptrend
                        trend = .up;
                        last_pivot_index = current_extreme_index;
                        last_pivot_price = current_extreme_price;
                        current_extreme_price = high;
                        current_extreme_index = i;
                    }
                }
            }
        }

        // Mark the first point as the starting price
        values[0] = series.arr_rows[0].f64_close;

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝