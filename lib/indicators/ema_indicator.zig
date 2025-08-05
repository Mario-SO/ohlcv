// ╔══════════════════════════════════════ EMA Indicator ══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const EmaIndicator = struct {
    const Self = @This();
    
    u32_period: u32,
    f64_smoothing: f64 = 2.0,
    
    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };
    
    /// Calculate Exponential Moving Average
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period) return Error.InsufficientData;
        
        const period = self.u32_period;
        const multiplier = self.f64_smoothing / @as(f64, @floatFromInt(period + 1));
        
        var values = try allocator.alloc(f64, series.len());
        errdefer allocator.free(values);
        
        var timestamps = try allocator.alloc(u64, series.len());
        errdefer allocator.free(timestamps);
        
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
        
        // Need to allocate new slices for the result
        const result_values = try allocator.dupe(f64, values[period - 1..]);
        const result_timestamps = try allocator.dupe(u64, timestamps[period - 1..]);
        
        // Free the original arrays
        allocator.free(values);
        allocator.free(timestamps);
        
        return .{
            .arr_values = result_values,
            .arr_timestamps = result_timestamps,
            .allocator = allocator,
        };
    }
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════╝