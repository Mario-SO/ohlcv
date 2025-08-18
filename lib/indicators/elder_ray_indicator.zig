// ╔══════════════════════════════════════ Elder Ray Indicator ════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;
const EmaIndicator = @import("ema_indicator.zig").EmaIndicator;

pub const ElderRayIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 13,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────────── Result ────────────────────────────────────────────┐

    pub const ElderRayResult = struct {
        bull_power: IndicatorResult,
        bear_power: IndicatorResult,

        pub fn deinit(self: *ElderRayResult) void {
            self.bull_power.deinit();
            self.bear_power.deinit();
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────── Calculate Elder Ray Index ────────────────────────────────────┐

    /// Calculate Elder Ray Index - Bull Power and Bear Power
    /// Bull Power = High - EMA(Close)
    /// Bear Power = Low - EMA(Close)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!ElderRayResult {
        if (self.u32_period == 0) {
            return Error.InvalidParameters;
        }
        if (series.len() < self.u32_period) {
            return Error.InsufficientData;
        }

        // Calculate EMA of closing prices
        const ema_indicator = EmaIndicator{ .u32_period = self.u32_period };
        var ema_result = try ema_indicator.calculate(series, allocator);
        defer ema_result.deinit();

        const result_len = ema_result.len();
        const start_offset = self.u32_period - 1;

        // Allocate arrays for bull power and bear power
        var bull_power_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(bull_power_values);

        var bear_power_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(bear_power_values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate Bull Power and Bear Power
        for (0..result_len) |i| {
            const data_index = i + start_offset;
            const ema_value = ema_result.arr_values[i];
            
            // Bull Power = High - EMA
            bull_power_values[i] = series.arr_rows[data_index].f64_high - ema_value;
            
            // Bear Power = Low - EMA  
            bear_power_values[i] = series.arr_rows[data_index].f64_low - ema_value;
            
            timestamps[i] = ema_result.arr_timestamps[i];
        }

        return ElderRayResult{
            .bull_power = .{
                .arr_values = bull_power_values,
                .arr_timestamps = try allocator.dupe(u64, timestamps),
                .allocator = allocator,
            },
            .bear_power = .{
                .arr_values = bear_power_values,
                .arr_timestamps = timestamps,
                .allocator = allocator,
            },
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝