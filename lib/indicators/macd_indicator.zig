// ╔════════════════════════════════════════ MACD Indicator ═══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;
const EmaIndicator = @import("ema_indicator.zig").EmaIndicator;

pub const MacdIndicator = struct {
    const Self = @This();

    u32_fast_period: u32 = 12,
    u32_slow_period: u32 = 26,
    u32_signal_period: u32 = 9,

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    pub const MacdResult = struct {
        macd_line: IndicatorResult,
        signal_line: IndicatorResult,
        histogram: IndicatorResult,
        
        pub fn deinit(self: *MacdResult) void {
            self.macd_line.deinit();
            self.signal_line.deinit();
            self.histogram.deinit();
        }
    };

    /// Calculate MACD (Moving Average Convergence Divergence)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!MacdResult {
        if (self.u32_fast_period == 0 or self.u32_slow_period == 0 or self.u32_signal_period == 0) {
            return Error.InvalidParameters;
        }
        if (self.u32_fast_period >= self.u32_slow_period) {
            return Error.InvalidParameters;
        }
        if (series.len() < self.u32_slow_period + self.u32_signal_period) {
            return Error.InsufficientData;
        }

        // Calculate fast and slow EMAs
        const fast_ema = EmaIndicator{ .u32_period = self.u32_fast_period };
        const slow_ema = EmaIndicator{ .u32_period = self.u32_slow_period };

        var fast_result = try fast_ema.calculate(series, allocator);
        defer fast_result.deinit();

        var slow_result = try slow_ema.calculate(series, allocator);
        defer slow_result.deinit();

        // Calculate MACD line (fast EMA - slow EMA)
        // Start from the slow EMA index since it starts later
        const start_offset = self.u32_slow_period - self.u32_fast_period;
        const macd_len = slow_result.len();
        
        var macd_values = try allocator.alloc(f64, macd_len);
        errdefer allocator.free(macd_values);
        
        var macd_timestamps = try allocator.alloc(u64, macd_len);
        errdefer allocator.free(macd_timestamps);

        for (0..macd_len) |i| {
            macd_values[i] = fast_result.arr_values[i + start_offset] - slow_result.arr_values[i];
            macd_timestamps[i] = slow_result.arr_timestamps[i];
        }

        // Create temporary time series for MACD values to calculate signal line
        var macd_rows = try allocator.alloc(@import("../types/ohlcv_row.zig").OhlcvRow, macd_len);
        defer allocator.free(macd_rows);
        
        for (0..macd_len) |i| {
            macd_rows[i] = .{
                .u64_timestamp = macd_timestamps[i],
                .f64_open = macd_values[i],
                .f64_high = macd_values[i],
                .f64_low = macd_values[i],
                .f64_close = macd_values[i],
                .u64_volume = 0,
            };
        }

        const macd_series = TimeSeries{
            .arr_rows = macd_rows,
            .allocator = allocator,
            .b_owns_memory = false,
        };

        // Calculate signal line (EMA of MACD line)
        const signal_ema = EmaIndicator{ .u32_period = self.u32_signal_period };
        var signal_result = try signal_ema.calculate(macd_series, allocator);

        // Calculate histogram (MACD - Signal)
        const histogram_len = signal_result.len();
        var histogram_values = try allocator.alloc(f64, histogram_len);
        errdefer allocator.free(histogram_values);
        
        var histogram_timestamps = try allocator.alloc(u64, histogram_len);
        errdefer allocator.free(histogram_timestamps);

        const signal_offset = self.u32_signal_period - 1;
        for (0..histogram_len) |i| {
            histogram_values[i] = macd_values[i + signal_offset] - signal_result.arr_values[i];
            histogram_timestamps[i] = signal_result.arr_timestamps[i];
        }

        // Create final MACD line with same length as signal/histogram
        var final_macd_values = try allocator.alloc(f64, histogram_len);
        errdefer allocator.free(final_macd_values);
        
        var final_macd_timestamps = try allocator.alloc(u64, histogram_len);
        errdefer allocator.free(final_macd_timestamps);

        for (0..histogram_len) |i| {
            final_macd_values[i] = macd_values[i + signal_offset];
            final_macd_timestamps[i] = histogram_timestamps[i];
        }

        // Free temporary MACD arrays
        allocator.free(macd_values);
        allocator.free(macd_timestamps);

        return MacdResult{
            .macd_line = .{
                .arr_values = final_macd_values,
                .arr_timestamps = final_macd_timestamps,
                .allocator = allocator,
            },
            .signal_line = signal_result,
            .histogram = .{
                .arr_values = histogram_values,
                .arr_timestamps = histogram_timestamps,
                .allocator = allocator,
            },
        };
    }
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝