// ╔══════════════════════════════════════════ CMF Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const CmfIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 20,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────────────── Calculate Chaikin Money Flow ─────────────────────────────────┐

    /// CMF = Sum(Money Flow Volume) / Sum(Volume) over period
    /// Money Flow Volume = Money Flow Multiplier × Volume
    /// Money Flow Multiplier = ((Close - Low) - (High - Close)) / (High - Low)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period + 1;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Precompute Money Flow Volumes
        var mf_volumes = try allocator.alloc(f64, series.len());
        defer allocator.free(mf_volumes);
        
        for (0..series.len()) |i| {
            const row = series.arr_rows[i];
            const high = row.f64_high;
            const low = row.f64_low;
            const close = row.f64_close;
            const volume = @as(f64, @floatFromInt(row.u64_volume));
            
            // Calculate Money Flow Multiplier
            const hl_range = high - low;
            const mf_multiplier = if (hl_range == 0.0) 0.0 else ((close - low) - (high - close)) / hl_range;
            
            // Calculate Money Flow Volume
            mf_volumes[i] = mf_multiplier * volume;
        }

        // Rolling window calculation
        var sum_mf_volume: f64 = 0.0;
        var sum_volume: f64 = 0.0;
        
        // Initialize first window
        for (0..period) |i| {
            sum_mf_volume += mf_volumes[i];
            sum_volume += @as(f64, @floatFromInt(series.arr_rows[i].u64_volume));
        }

        var i: usize = 0;
        while (i < result_len) : (i += 1) {
            // Calculate CMF for current window
            values[i] = if (sum_volume == 0.0) 0.0 else sum_mf_volume / sum_volume;
            timestamps[i] = series.arr_rows[i + period - 1].u64_timestamp;

            // Update rolling sums for next iteration
            if (i + 1 < result_len) {
                // Remove oldest value
                sum_mf_volume -= mf_volumes[i];
                sum_volume -= @as(f64, @floatFromInt(series.arr_rows[i].u64_volume));
                
                // Add newest value
                sum_mf_volume += mf_volumes[i + period];
                sum_volume += @as(f64, @floatFromInt(series.arr_rows[i + period].u64_volume));
            }
        }

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════════╝