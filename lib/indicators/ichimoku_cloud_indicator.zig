// ╔═══════════════════════════════════ Ichimoku Cloud Indicator ═══════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const IchimokuCloudIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_tenkan_period: u32 = 9,   // Conversion Line period
    u32_kijun_period: u32 = 26,   // Base Line period
    u32_senkou_period: u32 = 52,  // Leading Span B period
    u32_displacement: u32 = 26,   // Displacement for leading and lagging spans

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────────── Result ────────────────────────────────────────────┐

    pub const IchimokuCloudResult = struct {
        tenkan_sen: IndicatorResult,     // Conversion Line
        kijun_sen: IndicatorResult,      // Base Line
        senkou_span_a: IndicatorResult,  // Leading Span A (displaced forward)
        senkou_span_b: IndicatorResult,  // Leading Span B (displaced forward)
        chikou_span: IndicatorResult,    // Lagging Span (displaced backward)

        pub fn deinit(self: *IchimokuCloudResult) void {
            self.tenkan_sen.deinit();
            self.kijun_sen.deinit();
            self.senkou_span_a.deinit();
            self.senkou_span_b.deinit();
            self.chikou_span.deinit();
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────── Calculate Ichimoku Cloud Indicator ────────────────────────────┐

    /// Calculate Ichimoku Cloud with all five components:
    /// - Tenkan-sen (Conversion Line): (9-period high + 9-period low) / 2
    /// - Kijun-sen (Base Line): (26-period high + 26-period low) / 2
    /// - Senkou Span A (Leading Span A): (Tenkan-sen + Kijun-sen) / 2, plotted 26 periods ahead
    /// - Senkou Span B (Leading Span B): (52-period high + 52-period low) / 2, plotted 26 periods ahead
    /// - Chikou Span (Lagging Span): Close price plotted 26 periods behind
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IchimokuCloudResult {
        if (self.u32_tenkan_period == 0 or self.u32_kijun_period == 0 or 
            self.u32_senkou_period == 0 or self.u32_displacement == 0) {
            return Error.InvalidParameters;
        }

        // Need enough data for the longest period plus displacement
        const min_data_required = @max(self.u32_senkou_period, self.u32_displacement) + self.u32_displacement;
        if (series.len() < min_data_required) {
            return Error.InsufficientData;
        }

        // Calculate lengths for each component
        const tenkan_len = series.len() - self.u32_tenkan_period + 1;
        const kijun_len = series.len() - self.u32_kijun_period + 1;
        const senkou_b_len = series.len() - self.u32_senkou_period + 1;
        
        // For leading spans, we project forward by displacement periods
        _ = @max(kijun_len, senkou_b_len);
        
        // For lagging span, we use the close prices
        const chikou_len = series.len();

        // ┌─────────────────────────────────── Calculate Tenkan-sen ──────────────────────────────────┐

        var tenkan_values = try allocator.alloc(f64, tenkan_len);
        errdefer allocator.free(tenkan_values);
        
        var tenkan_timestamps = try allocator.alloc(u64, tenkan_len);
        errdefer allocator.free(tenkan_timestamps);

        for (0..tenkan_len) |i| {
            const window_start = i;
            const window_end = i + self.u32_tenkan_period;
            
            var highest = series.arr_rows[window_start].f64_high;
            var lowest = series.arr_rows[window_start].f64_low;
            
            for (series.arr_rows[window_start..window_end]) |row| {
                if (row.f64_high > highest) highest = row.f64_high;
                if (row.f64_low < lowest) lowest = row.f64_low;
            }
            
            tenkan_values[i] = (highest + lowest) / 2.0;
            tenkan_timestamps[i] = series.arr_rows[window_end - 1].u64_timestamp;
        }

        // └───────────────────────────────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────────────── Calculate Kijun-sen ─────────────────────────────────┐

        var kijun_values = try allocator.alloc(f64, kijun_len);
        errdefer allocator.free(kijun_values);
        
        var kijun_timestamps = try allocator.alloc(u64, kijun_len);
        errdefer allocator.free(kijun_timestamps);

        for (0..kijun_len) |i| {
            const window_start = i;
            const window_end = i + self.u32_kijun_period;
            
            var highest = series.arr_rows[window_start].f64_high;
            var lowest = series.arr_rows[window_start].f64_low;
            
            for (series.arr_rows[window_start..window_end]) |row| {
                if (row.f64_high > highest) highest = row.f64_high;
                if (row.f64_low < lowest) lowest = row.f64_low;
            }
            
            kijun_values[i] = (highest + lowest) / 2.0;
            kijun_timestamps[i] = series.arr_rows[window_end - 1].u64_timestamp;
        }

        // └───────────────────────────────────────────────────────────────────────────────────────────┘

        // ┌─────────────────────────────────── Calculate Senkou Span A ──────────────────────────────┐

        // Senkou Span A = (Tenkan-sen + Kijun-sen) / 2, displaced forward
        const senkou_a_calc_len = @min(tenkan_len, kijun_len);
        const tenkan_offset = if (tenkan_len > kijun_len) tenkan_len - kijun_len else 0;
        const kijun_offset = if (kijun_len > tenkan_len) kijun_len - tenkan_len else 0;

        var senkou_a_values = try allocator.alloc(f64, senkou_a_calc_len);
        errdefer allocator.free(senkou_a_values);
        
        var senkou_a_timestamps = try allocator.alloc(u64, senkou_a_calc_len);
        errdefer allocator.free(senkou_a_timestamps);

        for (0..senkou_a_calc_len) |i| {
            const tenkan_val = tenkan_values[i + tenkan_offset];
            const kijun_val = kijun_values[i + kijun_offset];
            
            senkou_a_values[i] = (tenkan_val + kijun_val) / 2.0;
            
            // Project timestamp forward by displacement periods
            _ = @max(tenkan_timestamps[i + tenkan_offset], kijun_timestamps[i + kijun_offset]);
            const displaced_index = i + @min(tenkan_offset, kijun_offset) + self.u32_displacement;
            
            if (displaced_index < series.len()) {
                senkou_a_timestamps[i] = series.arr_rows[displaced_index].u64_timestamp;
            } else {
                // Extrapolate timestamp beyond available data
                const time_diff = if (series.len() > 1) 
                    series.arr_rows[series.len() - 1].u64_timestamp - series.arr_rows[series.len() - 2].u64_timestamp
                else 
                    86400; // Default to 1 day if only one data point
                
                const periods_beyond = displaced_index - series.len() + 1;
                senkou_a_timestamps[i] = series.arr_rows[series.len() - 1].u64_timestamp + (time_diff * periods_beyond);
            }
        }

        // └───────────────────────────────────────────────────────────────────────────────────────────┘

        // ┌─────────────────────────────────── Calculate Senkou Span B ──────────────────────────────┐

        var senkou_b_values = try allocator.alloc(f64, senkou_b_len);
        errdefer allocator.free(senkou_b_values);
        
        var senkou_b_timestamps = try allocator.alloc(u64, senkou_b_len);
        errdefer allocator.free(senkou_b_timestamps);

        for (0..senkou_b_len) |i| {
            const window_start = i;
            const window_end = i + self.u32_senkou_period;
            
            var highest = series.arr_rows[window_start].f64_high;
            var lowest = series.arr_rows[window_start].f64_low;
            
            for (series.arr_rows[window_start..window_end]) |row| {
                if (row.f64_high > highest) highest = row.f64_high;
                if (row.f64_low < lowest) lowest = row.f64_low;
            }
            
            senkou_b_values[i] = (highest + lowest) / 2.0;
            
            // Project timestamp forward by displacement periods
            const displaced_index = window_end - 1 + self.u32_displacement;
            
            if (displaced_index < series.len()) {
                senkou_b_timestamps[i] = series.arr_rows[displaced_index].u64_timestamp;
            } else {
                // Extrapolate timestamp beyond available data
                const time_diff = if (series.len() > 1) 
                    series.arr_rows[series.len() - 1].u64_timestamp - series.arr_rows[series.len() - 2].u64_timestamp
                else 
                    86400; // Default to 1 day if only one data point
                
                const periods_beyond = displaced_index - series.len() + 1;
                senkou_b_timestamps[i] = series.arr_rows[series.len() - 1].u64_timestamp + (time_diff * periods_beyond);
            }
        }

        // └───────────────────────────────────────────────────────────────────────────────────────────┘

        // ┌──────────────────────────────────── Calculate Chikou Span ───────────────────────────────┐

        var chikou_values = try allocator.alloc(f64, chikou_len);
        errdefer allocator.free(chikou_values);
        
        var chikou_timestamps = try allocator.alloc(u64, chikou_len);
        errdefer allocator.free(chikou_timestamps);

        for (0..chikou_len) |i| {
            chikou_values[i] = series.arr_rows[i].f64_close;
            
            // Project timestamp backward by displacement periods
            if (i >= self.u32_displacement) {
                chikou_timestamps[i] = series.arr_rows[i - self.u32_displacement].u64_timestamp;
            } else {
                // Extrapolate timestamp before available data
                const time_diff = if (series.len() > 1) 
                    series.arr_rows[1].u64_timestamp - series.arr_rows[0].u64_timestamp
                else 
                    86400; // Default to 1 day if only one data point
                
                const periods_before = self.u32_displacement - i;
                chikou_timestamps[i] = series.arr_rows[0].u64_timestamp - (time_diff * periods_before);
            }
        }

        // └───────────────────────────────────────────────────────────────────────────────────────────┘

        return IchimokuCloudResult{
            .tenkan_sen = .{
                .arr_values = tenkan_values,
                .arr_timestamps = tenkan_timestamps,
                .allocator = allocator,
            },
            .kijun_sen = .{
                .arr_values = kijun_values,
                .arr_timestamps = kijun_timestamps,
                .allocator = allocator,
            },
            .senkou_span_a = .{
                .arr_values = senkou_a_values,
                .arr_timestamps = senkou_a_timestamps,
                .allocator = allocator,
            },
            .senkou_span_b = .{
                .arr_values = senkou_b_values,
                .arr_timestamps = senkou_b_timestamps,
                .allocator = allocator,
            },
            .chikou_span = .{
                .arr_values = chikou_values,
                .arr_timestamps = chikou_timestamps,
                .allocator = allocator,
            },
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝