// ╔═════════════════════════════════════════ ADX Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const AdxIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 14,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────────── Result ────────────────────────────────────────────┐

    pub const AdxResult = struct {
        adx: IndicatorResult,
        plus_di: IndicatorResult,
        minus_di: IndicatorResult,

        pub fn deinit(self: *AdxResult) void {
            self.adx.deinit();
            self.plus_di.deinit();
            self.minus_di.deinit();
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Calculate ADX (Average Directional Index) ────────────────────────┐

    /// Calculate ADX (Average Directional Index)
    /// Returns ADX, +DI, and -DI indicators for trend strength analysis
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!AdxResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        // Need at least 2 * period + 1 data points for stable ADX calculation
        if (series.len() < 2 * self.u32_period + 1) return Error.InsufficientData;

        const period = self.u32_period;
        const data_len = series.len();

        // Step 1: Calculate True Range, +DM, and -DM
        var true_ranges = try allocator.alloc(f64, data_len - 1);
        defer allocator.free(true_ranges);

        var plus_dm = try allocator.alloc(f64, data_len - 1);
        defer allocator.free(plus_dm);

        var minus_dm = try allocator.alloc(f64, data_len - 1);
        defer allocator.free(minus_dm);

        for (1..data_len) |i| {
            const current = series.arr_rows[i];
            const previous = series.arr_rows[i - 1];

            // Calculate True Range
            const high_low = current.f64_high - current.f64_low;
            const high_close_prev = @abs(current.f64_high - previous.f64_close);
            const low_close_prev = @abs(current.f64_low - previous.f64_close);
            true_ranges[i - 1] = @max(high_low, @max(high_close_prev, low_close_prev));

            // Calculate Directional Movement
            const up_move = current.f64_high - previous.f64_high;
            const down_move = previous.f64_low - current.f64_low;

            if (up_move > down_move and up_move > 0) {
                plus_dm[i - 1] = up_move;
            } else {
                plus_dm[i - 1] = 0;
            }

            if (down_move > up_move and down_move > 0) {
                minus_dm[i - 1] = down_move;
            } else {
                minus_dm[i - 1] = 0;
            }
        }

        // Step 2: Calculate smoothed values using Wilder's smoothing method
        var smoothed_tr = try allocator.alloc(f64, true_ranges.len - period + 1);
        defer allocator.free(smoothed_tr);

        var smoothed_plus_dm = try allocator.alloc(f64, plus_dm.len - period + 1);
        defer allocator.free(smoothed_plus_dm);

        var smoothed_minus_dm = try allocator.alloc(f64, minus_dm.len - period + 1);
        defer allocator.free(smoothed_minus_dm);

        // Calculate initial smoothed values (simple averages)
        var sum_tr: f64 = 0;
        var sum_plus_dm: f64 = 0;
        var sum_minus_dm: f64 = 0;

        for (0..period) |i| {
            sum_tr += true_ranges[i];
            sum_plus_dm += plus_dm[i];
            sum_minus_dm += minus_dm[i];
        }

        smoothed_tr[0] = sum_tr / @as(f64, @floatFromInt(period));
        smoothed_plus_dm[0] = sum_plus_dm / @as(f64, @floatFromInt(period));
        smoothed_minus_dm[0] = sum_minus_dm / @as(f64, @floatFromInt(period));

        // Apply Wilder's smoothing for subsequent values
        for (1..smoothed_tr.len) |i| {
            const idx = period - 1 + i;
            smoothed_tr[i] = (smoothed_tr[i - 1] * @as(f64, @floatFromInt(period - 1)) + true_ranges[idx]) / @as(f64, @floatFromInt(period));
            smoothed_plus_dm[i] = (smoothed_plus_dm[i - 1] * @as(f64, @floatFromInt(period - 1)) + plus_dm[idx]) / @as(f64, @floatFromInt(period));
            smoothed_minus_dm[i] = (smoothed_minus_dm[i - 1] * @as(f64, @floatFromInt(period - 1)) + minus_dm[idx]) / @as(f64, @floatFromInt(period));
        }

        // Step 3: Calculate +DI and -DI
        var dx_values = try allocator.alloc(f64, smoothed_tr.len);
        defer allocator.free(dx_values);

        const di_len = smoothed_tr.len;
        var plus_di_values = try allocator.alloc(f64, di_len);
        errdefer allocator.free(plus_di_values);

        var minus_di_values = try allocator.alloc(f64, di_len);
        errdefer allocator.free(minus_di_values);

        var di_timestamps = try allocator.alloc(u64, di_len);
        errdefer allocator.free(di_timestamps);

        for (0..di_len) |i| {
            const plus_di_val = if (smoothed_tr[i] != 0) (smoothed_plus_dm[i] / smoothed_tr[i]) * 100 else 0;
            const minus_di_val = if (smoothed_tr[i] != 0) (smoothed_minus_dm[i] / smoothed_tr[i]) * 100 else 0;

            plus_di_values[i] = plus_di_val;
            minus_di_values[i] = minus_di_val;
            di_timestamps[i] = series.arr_rows[period + i].u64_timestamp;

            // Calculate DX for ADX calculation
            const di_sum = plus_di_val + minus_di_val;
            if (di_sum != 0) {
                dx_values[i] = @abs(plus_di_val - minus_di_val) / di_sum * 100;
            } else {
                dx_values[i] = 0;
            }
        }

        // Step 4: Calculate ADX (smoothed DX)
        const adx_len = dx_values.len - period + 1;
        var adx_values = try allocator.alloc(f64, adx_len);
        errdefer allocator.free(adx_values);

        var adx_timestamps = try allocator.alloc(u64, adx_len);
        errdefer allocator.free(adx_timestamps);

        // Calculate initial ADX as simple average of first period DX values
        var sum_dx: f64 = 0;
        for (0..period) |i| {
            sum_dx += dx_values[i];
        }
        adx_values[0] = sum_dx / @as(f64, @floatFromInt(period));
        adx_timestamps[0] = series.arr_rows[2 * period - 1].u64_timestamp;

        // Apply Wilder's smoothing for subsequent ADX values
        for (1..adx_len) |i| {
            const current_dx = dx_values[period - 1 + i];
            adx_values[i] = (adx_values[i - 1] * @as(f64, @floatFromInt(period - 1)) + current_dx) / @as(f64, @floatFromInt(period));
            adx_timestamps[i] = series.arr_rows[2 * period - 1 + i].u64_timestamp;
        }

        // Step 5: Trim +DI and -DI to match ADX length
        const final_plus_di_values = try allocator.alloc(f64, adx_len);
        errdefer allocator.free(final_plus_di_values);

        const final_minus_di_values = try allocator.alloc(f64, adx_len);
        errdefer allocator.free(final_minus_di_values);

        const final_plus_di_timestamps = try allocator.alloc(u64, adx_len);
        errdefer allocator.free(final_plus_di_timestamps);
        
        const final_minus_di_timestamps = try allocator.alloc(u64, adx_len);
        errdefer allocator.free(final_minus_di_timestamps);

        const di_offset = period - 1;
        for (0..adx_len) |i| {
            final_plus_di_values[i] = plus_di_values[di_offset + i];
            final_minus_di_values[i] = minus_di_values[di_offset + i];
            final_plus_di_timestamps[i] = adx_timestamps[i];
            final_minus_di_timestamps[i] = adx_timestamps[i];
        }

        // Clean up temporary arrays
        allocator.free(plus_di_values);
        allocator.free(minus_di_values);
        allocator.free(di_timestamps);

        return AdxResult{
            .adx = .{
                .arr_values = adx_values,
                .arr_timestamps = adx_timestamps,
                .allocator = allocator,
            },
            .plus_di = .{
                .arr_values = final_plus_di_values,
                .arr_timestamps = final_plus_di_timestamps,
                .allocator = allocator,
            },
            .minus_di = .{
                .arr_values = final_minus_di_values,
                .arr_timestamps = final_minus_di_timestamps,
                .allocator = allocator,
            },
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝