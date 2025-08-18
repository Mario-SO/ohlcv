// ╔═══════════════════════════════════ Heikin Ashi Indicator ══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const HeikinAshiIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    // No parameters needed - this is a pure transformation

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────────── Result ────────────────────────────────────────────┐

    pub const HeikinAshiResult = struct {
        ha_open: IndicatorResult,
        ha_high: IndicatorResult,
        ha_low: IndicatorResult,
        ha_close: IndicatorResult,

        pub fn deinit(self: *HeikinAshiResult) void {
            self.ha_open.deinit();
            self.ha_high.deinit();
            self.ha_low.deinit();
            self.ha_close.deinit();
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────── Calculate Heikin Ashi Smoothed Candles ─────────────────────────────┐

    /// Calculate Heikin Ashi candles for smoother trend analysis
    /// HA-Close = (Open + High + Low + Close) / 4
    /// HA-Open = (Previous HA-Open + Previous HA-Close) / 2
    /// HA-High = Max(High, HA-Open, HA-Close)
    /// HA-Low = Min(Low, HA-Open, HA-Close)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!HeikinAshiResult {
        _ = self; // No parameters needed for this transformation
        
        if (series.len() == 0) return Error.InsufficientData;

        const result_len = series.len();

        // Allocate arrays for all four OHLC components
        var ha_open_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(ha_open_values);

        var ha_high_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(ha_high_values);

        var ha_low_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(ha_low_values);

        var ha_close_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(ha_close_values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Initialize first Heikin Ashi candle
        const first_row = series.arr_rows[0];
        
        // For the first candle, HA-Open = (Open + Close) / 2
        ha_open_values[0] = (first_row.f64_open + first_row.f64_close) / 2.0;
        
        // HA-Close = (Open + High + Low + Close) / 4
        ha_close_values[0] = (first_row.f64_open + first_row.f64_high + first_row.f64_low + first_row.f64_close) / 4.0;
        
        // HA-High = Max(High, HA-Open, HA-Close)
        ha_high_values[0] = @max(@max(first_row.f64_high, ha_open_values[0]), ha_close_values[0]);
        
        // HA-Low = Min(Low, HA-Open, HA-Close)
        ha_low_values[0] = @min(@min(first_row.f64_low, ha_open_values[0]), ha_close_values[0]);
        
        timestamps[0] = first_row.u64_timestamp;

        // Calculate remaining Heikin Ashi candles
        for (1..result_len) |i| {
            const current_row = series.arr_rows[i];
            
            // HA-Close = (Open + High + Low + Close) / 4
            ha_close_values[i] = (current_row.f64_open + current_row.f64_high + current_row.f64_low + current_row.f64_close) / 4.0;
            
            // HA-Open = (Previous HA-Open + Previous HA-Close) / 2
            ha_open_values[i] = (ha_open_values[i - 1] + ha_close_values[i - 1]) / 2.0;
            
            // HA-High = Max(High, HA-Open, HA-Close)
            ha_high_values[i] = @max(@max(current_row.f64_high, ha_open_values[i]), ha_close_values[i]);
            
            // HA-Low = Min(Low, HA-Open, HA-Close)
            ha_low_values[i] = @min(@min(current_row.f64_low, ha_open_values[i]), ha_close_values[i]);
            
            timestamps[i] = current_row.u64_timestamp;
        }

        // Create separate timestamp arrays for each component
        const ha_open_timestamps = try allocator.dupe(u64, timestamps);
        const ha_high_timestamps = try allocator.dupe(u64, timestamps);
        const ha_low_timestamps = try allocator.dupe(u64, timestamps);
        const ha_close_timestamps = try allocator.dupe(u64, timestamps);

        allocator.free(timestamps);

        return HeikinAshiResult{
            .ha_open = .{
                .arr_values = ha_open_values,
                .arr_timestamps = ha_open_timestamps,
                .allocator = allocator,
            },
            .ha_high = .{
                .arr_values = ha_high_values,
                .arr_timestamps = ha_high_timestamps,
                .allocator = allocator,
            },
            .ha_low = .{
                .arr_values = ha_low_values,
                .arr_timestamps = ha_low_timestamps,
                .allocator = allocator,
            },
            .ha_close = .{
                .arr_values = ha_close_values,
                .arr_timestamps = ha_close_timestamps,
                .allocator = allocator,
            },
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝