// ╔═══════════════════════════════════ Keltner Channels Indicator ═════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const KeltnerChannelsIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_ema_period: u32 = 20,
    u32_atr_period: u32 = 10,
    f64_multiplier: f64 = 2.0,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────────── Result ────────────────────────────────────────────┐

    pub const KeltnerChannelsResult = struct {
        upper_channel: IndicatorResult,
        middle_line: IndicatorResult, // EMA
        lower_channel: IndicatorResult,

        pub fn deinit(self: *KeltnerChannelsResult) void {
            self.upper_channel.deinit();
            self.middle_line.deinit();
            self.lower_channel.deinit();
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────── Calculate Keltner Channels using EMA and ATR ───────────────────────────────┐

    /// Calculate Keltner Channels (Upper, Middle, Lower)
    /// Middle Line = EMA of closing prices
    /// Upper Channel = EMA + (ATR × multiplier)
    /// Lower Channel = EMA - (ATR × multiplier)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!KeltnerChannelsResult {
        if (self.u32_ema_period == 0 or self.u32_atr_period == 0) return Error.InvalidParameters;
        
        // Need enough data for both EMA and ATR calculations
        const min_data_needed = @max(self.u32_ema_period, self.u32_atr_period + 1);
        if (series.len() < min_data_needed) return Error.InsufficientData;

        // Calculate EMA
        const ema_values = try allocator.alloc(f64, series.len());
        defer allocator.free(ema_values);
        
        const ema_timestamps = try allocator.alloc(u64, series.len());
        defer allocator.free(ema_timestamps);

        try self.calculateEMA(series, ema_values, ema_timestamps);

        // Calculate ATR
        const atr_values = try allocator.alloc(f64, series.len() - 1);
        defer allocator.free(atr_values);
        
        const atr_timestamps = try allocator.alloc(u64, series.len() - 1);
        defer allocator.free(atr_timestamps);

        try self.calculateATR(series, atr_values, atr_timestamps);

        // Determine the overlap period where we have both EMA and ATR
        const ema_start_idx = self.u32_ema_period - 1;
        const atr_start_idx = self.u32_atr_period;
        const result_start_idx = @max(ema_start_idx, atr_start_idx);
        const result_len = series.len() - result_start_idx;

        // Allocate arrays for all three channels
        var upper_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(upper_values);

        var middle_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(middle_values);

        var lower_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(lower_values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate channels
        for (0..result_len) |i| {
            const series_idx = result_start_idx + i;
            const ema_idx = series_idx;
            const atr_idx = series_idx - 1; // ATR array is offset by 1

            const ema_value = ema_values[ema_idx];
            const atr_value = atr_values[atr_idx];
            const channel_offset = atr_value * self.f64_multiplier;

            middle_values[i] = ema_value;
            upper_values[i] = ema_value + channel_offset;
            lower_values[i] = ema_value - channel_offset;
            timestamps[i] = series.arr_rows[series_idx].u64_timestamp;
        }

        // Create separate timestamp arrays for each channel
        const upper_timestamps = try allocator.dupe(u64, timestamps);
        const middle_timestamps = try allocator.dupe(u64, timestamps);
        const lower_timestamps = try allocator.dupe(u64, timestamps);

        allocator.free(timestamps);

        return KeltnerChannelsResult{
            .upper_channel = .{
                .arr_values = upper_values,
                .arr_timestamps = upper_timestamps,
                .allocator = allocator,
            },
            .middle_line = .{
                .arr_values = middle_values,
                .arr_timestamps = middle_timestamps,
                .allocator = allocator,
            },
            .lower_channel = .{
                .arr_values = lower_values,
                .arr_timestamps = lower_timestamps,
                .allocator = allocator,
            },
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────── Helper Functions ──────────────────────────────────────────┐

    /// Calculate EMA values
    fn calculateEMA(self: Self, series: TimeSeries, values: []f64, timestamps: []u64) Error!void {
        const period = self.u32_ema_period;
        const multiplier = 2.0 / @as(f64, @floatFromInt(period + 1));

        // Calculate initial SMA as starting point
        var sum: f64 = 0;
        for (series.arr_rows[0..period]) |row| {
            sum += row.f64_close;
        }

        // First EMA value is the SMA
        var ema = sum / @as(f64, @floatFromInt(period));
        values[period - 1] = ema;
        timestamps[period - 1] = series.arr_rows[period - 1].u64_timestamp;

        // Calculate subsequent EMA values
        var i: usize = period;
        while (i < series.len()) : (i += 1) {
            ema = (series.arr_rows[i].f64_close - ema) * multiplier + ema;
            values[i] = ema;
            timestamps[i] = series.arr_rows[i].u64_timestamp;
        }
    }

    /// Calculate ATR values
    fn calculateATR(self: Self, series: TimeSeries, values: []f64, timestamps: []u64) Error!void {
        const period = self.u32_atr_period;

        // Calculate True Range for each bar (starting from index 1)
        var true_ranges = try std.heap.page_allocator.alloc(f64, series.len() - 1);
        defer std.heap.page_allocator.free(true_ranges);

        for (1..series.len()) |i| {
            const current = series.arr_rows[i];
            const previous = series.arr_rows[i - 1];

            const high_low = current.f64_high - current.f64_low;
            const high_close_prev = @abs(current.f64_high - previous.f64_close);
            const low_close_prev = @abs(current.f64_low - previous.f64_close);

            true_ranges[i - 1] = @max(high_low, @max(high_close_prev, low_close_prev));
        }

        const result_len = true_ranges.len - period + 1;

        // Calculate first ATR as simple average
        var sum: f64 = 0;
        for (true_ranges[0..period]) |tr| {
            sum += tr;
        }
        var atr = sum / @as(f64, @floatFromInt(period));
        values[period - 1] = atr;
        timestamps[period - 1] = series.arr_rows[period].u64_timestamp;

        // Calculate subsequent ATR values using Wilder's smoothing
        // ATR = (Previous ATR * (n-1) + Current TR) / n
        var i: usize = 1;
        while (i < result_len) : (i += 1) {
            const current_tr = true_ranges[period - 1 + i];
            atr = (atr * @as(f64, @floatFromInt(period - 1)) + current_tr) / @as(f64, @floatFromInt(period));
            values[period - 1 + i] = atr;
            timestamps[period - 1 + i] = series.arr_rows[period + i].u64_timestamp;
        }
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝