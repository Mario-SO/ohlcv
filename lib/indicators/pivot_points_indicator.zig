// ╔═══════════════════════════════════ Pivot Points Indicator ════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const PivotPointsIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    // Pivot Points don't have configurable parameters - they use the previous day's High, Low, Close

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌─────────────────────────────────────────── Result ────────────────────────────────────────────┐

    pub const PivotPointsResult = struct {
        pivot_point: IndicatorResult,
        support_1: IndicatorResult,
        support_2: IndicatorResult,
        resistance_1: IndicatorResult,
        resistance_2: IndicatorResult,

        pub fn deinit(self: *PivotPointsResult) void {
            self.pivot_point.deinit();
            self.support_1.deinit();
            self.support_2.deinit();
            self.resistance_1.deinit();
            self.resistance_2.deinit();
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────── Calculate Pivot Points and Support/Resistance ───────────────────────┐

    /// Calculate Pivot Points with Support and Resistance levels
    /// 
    /// Formulas:
    /// - Pivot Point (P) = (High + Low + Close) / 3
    /// - Support 1 (S1) = (2 × P) - High
    /// - Support 2 (S2) = P - (High - Low)  
    /// - Resistance 1 (R1) = (2 × P) - Low
    /// - Resistance 2 (R2) = P + (High - Low)
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!PivotPointsResult {
        _ = self; // Pivot points don't use any parameters
        
        if (series.len() < 2) return Error.InsufficientData;

        // Calculate pivot points starting from the second data point
        // (using previous day's data to calculate current day's pivots)
        const result_len = series.len() - 1;

        // Allocate arrays for all five levels
        var pivot_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(pivot_values);

        var s1_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(s1_values);

        var s2_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(s2_values);

        var r1_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(r1_values);

        var r2_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(r2_values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Calculate pivot points for each day
        for (0..result_len) |i| {
            // Use previous day's OHLC data for calculation
            const prev_row = series.arr_rows[i];
            const curr_row = series.arr_rows[i + 1];
            
            const high = prev_row.f64_high;
            const low = prev_row.f64_low;
            const close = prev_row.f64_close;
            
            // Calculate Pivot Point
            const pivot = (high + low + close) / 3.0;
            
            // Calculate Support and Resistance levels
            const support_1 = (2.0 * pivot) - high;
            const support_2 = pivot - (high - low);
            const resistance_1 = (2.0 * pivot) - low;
            const resistance_2 = pivot + (high - low);
            
            // Store calculated values
            pivot_values[i] = pivot;
            s1_values[i] = support_1;
            s2_values[i] = support_2;
            r1_values[i] = resistance_1;
            r2_values[i] = resistance_2;
            
            // Use current day's timestamp
            timestamps[i] = curr_row.u64_timestamp;
        }

        // Create separate timestamp arrays for each level
        const pivot_timestamps = try allocator.dupe(u64, timestamps);
        errdefer allocator.free(pivot_timestamps);

        const s1_timestamps = try allocator.dupe(u64, timestamps);
        errdefer allocator.free(s1_timestamps);

        const s2_timestamps = try allocator.dupe(u64, timestamps);
        errdefer allocator.free(s2_timestamps);

        const r1_timestamps = try allocator.dupe(u64, timestamps);
        errdefer allocator.free(r1_timestamps);

        const r2_timestamps = try allocator.dupe(u64, timestamps);
        errdefer allocator.free(r2_timestamps);

        allocator.free(timestamps);

        return PivotPointsResult{
            .pivot_point = .{
                .arr_values = pivot_values,
                .arr_timestamps = pivot_timestamps,
                .allocator = allocator,
            },
            .support_1 = .{
                .arr_values = s1_values,
                .arr_timestamps = s1_timestamps,
                .allocator = allocator,
            },
            .support_2 = .{
                .arr_values = s2_values,
                .arr_timestamps = s2_timestamps,
                .allocator = allocator,
            },
            .resistance_1 = .{
                .arr_values = r1_values,
                .arr_timestamps = r1_timestamps,
                .allocator = allocator,
            },
            .resistance_2 = .{
                .arr_values = r2_values,
                .arr_timestamps = r2_timestamps,
                .allocator = allocator,
            },
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝