// ╔════════════════════════════════════════ MFI Indicator ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const TimeSeries = @import("../utils/time_series.zig").TimeSeries;
const IndicatorResult = @import("indicator_result.zig").IndicatorResult;

pub const MfiIndicator = struct {
    const Self = @This();

    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐

    u32_period: u32 = 14,

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────────────── Error ────────────────────────────────────────────┐

    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘

    // ┌──────────────────────────────────── Calculate Money Flow Index ───────────────────────────────┐

    /// Calculate Money Flow Index (MFI)
    /// MFI = 100 - (100 / (1 + Money Flow Ratio))
    /// where Money Flow Ratio = Positive Money Flow / Negative Money Flow
    /// Raw Money Flow = Typical Price × Volume
    /// Typical Price = (High + Low + Close) / 3
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        if (self.u32_period == 0) return Error.InvalidParameters;
        if (series.len() <= self.u32_period) return Error.InsufficientData;

        const period = self.u32_period;
        const result_len = series.len() - period;

        var values = try allocator.alloc(f64, result_len);
        errdefer allocator.free(values);

        var timestamps = try allocator.alloc(u64, result_len);
        errdefer allocator.free(timestamps);

        // Pre-calculate typical prices and raw money flows
        var typical_prices = try allocator.alloc(f64, series.len());
        defer allocator.free(typical_prices);

        var raw_money_flows = try allocator.alloc(f64, series.len());
        defer allocator.free(raw_money_flows);

        for (0..series.len()) |i| {
            const row = series.arr_rows[i];
            typical_prices[i] = (row.f64_high + row.f64_low + row.f64_close) / 3.0;
            raw_money_flows[i] = typical_prices[i] * @as(f64, @floatFromInt(row.u64_volume));
        }

        // Calculate MFI for each period
        var i: usize = 1; // Start from 1 since we need previous typical price
        while (i <= period) : (i += 1) {
            var positive_mf: f64 = 0;
            var negative_mf: f64 = 0;

            // Look at the current period window
            var j: usize = i;
            while (j <= i + period - 1) : (j += 1) {
                if (typical_prices[j] > typical_prices[j - 1]) {
                    positive_mf += raw_money_flows[j];
                } else if (typical_prices[j] < typical_prices[j - 1]) {
                    negative_mf += raw_money_flows[j];
                }
                // If typical_prices[j] == typical_prices[j - 1], add nothing to either
            }

            const mfi = if (negative_mf == 0) 100.0 else blk: {
                const money_flow_ratio = positive_mf / negative_mf;
                break :blk 100.0 - (100.0 / (1.0 + money_flow_ratio));
            };

            values[i - 1] = mfi;
            timestamps[i - 1] = series.arr_rows[i + period - 1].u64_timestamp;
        }

        // Calculate remaining MFI values
        while (i < series.len()) : (i += 1) {
            var positive_mf: f64 = 0;
            var negative_mf: f64 = 0;

            // Look at the current period window
            var j: usize = i - period + 1;
            while (j <= i) : (j += 1) {
                if (typical_prices[j] > typical_prices[j - 1]) {
                    positive_mf += raw_money_flows[j];
                } else if (typical_prices[j] < typical_prices[j - 1]) {
                    negative_mf += raw_money_flows[j];
                }
            }

            const mfi = if (negative_mf == 0) 100.0 else blk: {
                const money_flow_ratio = positive_mf / negative_mf;
                break :blk 100.0 - (100.0 / (1.0 + money_flow_ratio));
            };

            values[i - period] = mfi;
            timestamps[i - period] = series.arr_rows[i].u64_timestamp;
        }

        return .{
            .arr_values = values,
            .arr_timestamps = timestamps,
            .allocator = allocator,
        };
    }

    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝