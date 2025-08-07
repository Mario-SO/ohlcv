// ╔════════════════════════════════════ Donchian Channels Indicator ════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const DonchianChannelsIndicator = struct {
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

    // ┌─────────────────────────────────────────── Result ────────────────────────────────────────────┐

    pub const DonchianResult = struct {
        upper_band: IndicatorResult,
        middle_band: IndicatorResult,
        lower_band: IndicatorResult,

        pub fn deinit(self: *DonchianResult) void {
            self.upper_band.deinit();
            self.middle_band.deinit();
            self.lower_band.deinit();
        }
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌────────────────────────────── Calculate Donchian Channels (Hn, (Hn+Ln)/2, Ln) ────────────────┐

    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!DonchianResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() < self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period + 1;

        var upper_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(upper_values);

        var middle_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(middle_values);

        var lower_values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(lower_values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        var i: usize = 0;
        while (i < result_len) : (i += 1) {
            var highest_high = series.arr_rows[i].f64_high;
            var lowest_low = series.arr_rows[i].f64_low;

            var j: usize = 0;
            while (j < period) : (j += 1) {
                const row = series.arr_rows[i + j];
                if (row.f64_high > highest_high) highest_high = row.f64_high;
                if (row.f64_low < lowest_low) lowest_low = row.f64_low;
            }

            upper_values[i] = highest_high;
            lower_values[i] = lowest_low;
            middle_values[i] = (highest_high + lowest_low) / 2.0;
            timestamps[i] = series.arr_rows[i + period - 1].u64_timestamp;
        }

        const upper_ts = try allocator.dupe(u64, timestamps);
        const middle_ts = try allocator.dupe(u64, timestamps);
        const lower_ts = try allocator.dupe(u64, timestamps);
        allocator.free(timestamps);

        return DonchianResult{
            .upper_band = .{ .arr_values = upper_values, .arr_timestamps = upper_ts, .allocator = allocator },
            .middle_band = .{ .arr_values = middle_values, .arr_timestamps = middle_ts, .allocator = allocator },
            .lower_band = .{ .arr_values = lower_values, .arr_timestamps = lower_ts, .allocator = allocator },
        };
    }
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════════╝
