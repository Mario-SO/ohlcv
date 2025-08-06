// ╔══════════════════════════════════════ Stochastic Indicator ═══════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const StochasticIndicator = struct {
    const Self = @This();

    u32_k_period: u32 = 14,    // %K period (lookback for highest high and lowest low)
    u32_k_slowing: u32 = 1,    // %K slowing period (SMA of raw %K)
    u32_d_period: u32 = 3,     // %D period (SMA of %K)

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    pub const StochasticResult = struct {
        k_percent: IndicatorResult,  // %K line
        d_percent: IndicatorResult,  // %D line
        
        pub fn deinit(self: *StochasticResult) void {
            self.k_percent.deinit();
            self.d_percent.deinit();
        }
    };

    /// Calculate Stochastic Oscillator (%K and %D)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!StochasticResult {
        if (self.u32_k_period == 0 or self.u32_k_slowing == 0 or self.u32_d_period == 0) {
            return Error.InvalidParameters;
        }
        
        const min_data_needed = self.u32_k_period + self.u32_k_slowing + self.u32_d_period - 2;
        if (series.len() < min_data_needed) return Error.InsufficientData;

        // Step 1: Calculate raw %K values
        const raw_k_len = series.len() - self.u32_k_period + 1;
        var raw_k_values = try allocator.alloc(f64, raw_k_len);
        defer allocator.free(raw_k_values);

        for (0..raw_k_len) |i| {
            const window_start = i;
            const window_end = i + self.u32_k_period;
            
            // Find highest high and lowest low in the period
            var highest_high = series.arr_rows[window_start].f64_high;
            var lowest_low = series.arr_rows[window_start].f64_low;
            
            for (series.arr_rows[window_start..window_end]) |row| {
                if (row.f64_high > highest_high) highest_high = row.f64_high;
                if (row.f64_low < lowest_low) lowest_low = row.f64_low;
            }
            
            // Calculate raw %K
            const current_close = series.arr_rows[window_end - 1].f64_close;
            const range = highest_high - lowest_low;
            
            raw_k_values[i] = if (range == 0) 50.0 else ((current_close - lowest_low) / range) * 100.0;
        }

        // Step 2: Apply slowing to %K (SMA of raw %K)
        const k_len = raw_k_len - self.u32_k_slowing + 1;
        var k_values = try allocator.alloc(f64, k_len);
        errdefer allocator.free(k_values);
        
        var k_timestamps = try allocator.alloc(u64, k_len);
        errdefer allocator.free(k_timestamps);

        for (0..k_len) |i| {
            var sum: f64 = 0;
            for (raw_k_values[i..i + self.u32_k_slowing]) |val| {
                sum += val;
            }
            k_values[i] = sum / @as(f64, @floatFromInt(self.u32_k_slowing));
            k_timestamps[i] = series.arr_rows[i + self.u32_k_period + self.u32_k_slowing - 2].u64_timestamp;
        }

        // Step 3: Calculate %D (SMA of %K)
        const d_len = k_len - self.u32_d_period + 1;
        var d_values = try allocator.alloc(f64, d_len);
        errdefer allocator.free(d_values);
        
        var d_timestamps = try allocator.alloc(u64, d_len);
        errdefer allocator.free(d_timestamps);

        for (0..d_len) |i| {
            var sum: f64 = 0;
            for (k_values[i..i + self.u32_d_period]) |val| {
                sum += val;
            }
            d_values[i] = sum / @as(f64, @floatFromInt(self.u32_d_period));
            d_timestamps[i] = k_timestamps[i + self.u32_d_period - 1];
        }

        // Align %K values with %D (take the last d_len values)
        const k_start = k_len - d_len;
        const final_k_values = try allocator.alloc(f64, d_len);
        errdefer allocator.free(final_k_values);
        
        const final_k_timestamps = try allocator.alloc(u64, d_len);
        errdefer allocator.free(final_k_timestamps);

        @memcpy(final_k_values, k_values[k_start..]);
        @memcpy(final_k_timestamps, k_timestamps[k_start..]);

        // Free intermediate arrays
        allocator.free(k_values);
        allocator.free(k_timestamps);

        return StochasticResult{
            .k_percent = .{
                .arr_values = final_k_values,
                .arr_timestamps = final_k_timestamps,
                .allocator = allocator,
            },
            .d_percent = .{
                .arr_values = d_values,
                .arr_timestamps = d_timestamps,
                .allocator = allocator,
            },
        };
    }
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝