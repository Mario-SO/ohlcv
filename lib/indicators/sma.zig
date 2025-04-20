const std = @import("std");
const Row = @import("../types/row.zig").Row;
const Bar = @import("../types/bar.zig").Bar;
const Allocator = std.mem.Allocator;

pub const SmaOptions = struct {
    period: u32,
};

pub const SMAError = error{
    InsufficientData, // Not enough data points for the period
    InvalidParameters, // e.g., period = 0
    OutOfMemory,
};

/// Calculates the Simple Moving Average (SMA) for a given period on provided data.
/// Takes ownership of the input data slice conceptually (doesn't modify).
/// Returns an allocated slice of Bar structs where 'c' holds the SMA value, or an error.
pub fn calculateSMA(
    data: []const Row,
    options: SmaOptions,
    alloc: Allocator,
) SMAError![]Bar {
    const period = options.period;

    if (period == 0) return error.InvalidParameters;
    if (data.len < period) return error.InsufficientData;

    var sma_results = std.ArrayList(Bar).init(alloc);
    errdefer sma_results.deinit();

    var sum: f64 = 0;
    for (data[0..period]) |row| {
        sum += row.c;
    }

    const first_sma_value = sum / @as(f64, @floatFromInt(period));
    try sma_results.append(Bar{
        .ts = data[period - 1].ts,
        .o = 0,
        .h = 0,
        .l = 0,
        .c = first_sma_value,
    });

    var i: usize = period;
    while (i < data.len) : (i += 1) {
        sum -= data[i - period].c;
        sum += data[i].c;
        const sma_value = sum / @as(f64, @floatFromInt(period));
        try sma_results.append(Bar{
            .ts = data[i].ts,
            .o = 0,
            .h = 0,
            .l = 0,
            .c = sma_value,
        });
    }

    return sma_results.toOwnedSlice() catch |err| {
        // Catch potential allocation error from toOwnedSlice if list was empty maybe?
        // Or if underlying allocator fails copy. Re-tag as OutOfMemory.
        if (err == error.OutOfMemory) return error.OutOfMemory;
        // This path shouldn't realistically be hit for other errors here.
        return error.OutOfMemory;
    };
}
