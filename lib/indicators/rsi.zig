const std = @import("std");
const math = std.math;
const Row = @import("../types/row.zig").Row;
const Bar = @import("../types/bar.zig").Bar;
const Allocator = std.mem.Allocator;

pub const RsiOptions = struct {
    period: u32 = 14, // Default period is 14
};

pub const RSIError = error{
    InsufficientData,
    InvalidParameters,
    OutOfMemory,
};

pub fn calculateRSI(
    data: []const Row,
    options: RsiOptions,
    alloc: Allocator,
) RSIError![]Bar {
    const period: usize = @intCast(options.period);

    if (period == 0) return error.InvalidParameters;
    // Need at least 'period' prices to calculate the first change,
    // and then 'period' changes to calculate the first average.
    // So, need period + 1 data points.
    if (data.len <= period) return error.InsufficientData;

    var rsi_results = std.ArrayList(Bar).init(alloc);
    errdefer rsi_results.deinit();

    var gains_sum: f64 = 0;
    var losses_sum: f64 = 0;

    // Calculate initial average gain and loss
    var i: usize = 1;
    while (i <= period) : (i += 1) {
        const change = data[i].c - data[i - 1].c;
        if (change > 0) {
            gains_sum += change;
        } else {
            losses_sum += -change; // Use positive value for loss
        }
    }

    var avg_gain = gains_sum / @as(f64, @floatFromInt(period));
    var avg_loss = losses_sum / @as(f64, @floatFromInt(period));

    const first_rsi: f64 = blk: {
        if (avg_loss == 0) {
            // Avoid division by zero; RSI is 100 if avg_loss is 0
            break :blk 100.0;
        }
        const rs = avg_gain / avg_loss;
        break :blk 100.0 - (100.0 / (1.0 + rs));
    };

    try rsi_results.append(Bar{
        .ts = data[period].ts, // RSI value corresponds to the end of the period
        .o = 0,
        .h = 0,
        .l = 0,
        .c = first_rsi,
    });

    // Calculate subsequent RSI values using smoothing
    while (i < data.len) : (i += 1) {
        const change = data[i].c - data[i - 1].c;
        var current_gain: f64 = 0;
        var current_loss: f64 = 0;

        if (change > 0) {
            current_gain = change;
        } else {
            current_loss = -change; // Use positive value for loss
        }

        // Smoothed average gain/loss using Wilder's smoothing method (as commonly used for RSI)
        // Equivalent to the article's Step Two formula where alpha = 1 / period
        avg_gain = (avg_gain * @as(f64, @floatFromInt(period - 1)) + current_gain) / @as(f64, @floatFromInt(period));
        avg_loss = (avg_loss * @as(f64, @floatFromInt(period - 1)) + current_loss) / @as(f64, @floatFromInt(period));

        const rsi: f64 = blk: {
            if (avg_loss == 0) {
                break :blk 100.0;
            }
            const rs = avg_gain / avg_loss;
            break :blk 100.0 - (100.0 / (1.0 + rs));
        };

        try rsi_results.append(Bar{
            .ts = data[i].ts,
            .o = 0,
            .h = 0,
            .l = 0,
            .c = rsi,
        });
    }

    return rsi_results.toOwnedSlice() catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        // Should not happen for other errors
        return error.OutOfMemory;
    };
}
