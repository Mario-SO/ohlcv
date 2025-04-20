const std = @import("std");
const print = std.debug.print;
const Row = @import("../types/row.zig").Row;
const Bar = @import("../types/bar.zig").Bar;
const date_util = @import("../util/date.zig");
const DataSet = @import("../provider/provider.zig").DataSet;
const GetRowsError = date_util.GetRowsError;

// Define an error set for SMA calculation itself
const SMAError = error{
    InsufficientData, // Not enough data points for the period
    OutOfMemory,
};

// Define a combined error set for the public function
pub const MAError = GetRowsError || SMAError;

// ┌─────────────────────────── calculateSMA (Internal) ────────────────────────────┐

/// Calculates the Simple Moving Average (SMA) for a given period on provided data.
/// Returns a slice of Bar structs where 'c' holds the SMA value.
fn calculateSMA(
    period: u32,
    data: []const Row,
    alloc: std.mem.Allocator,
) SMAError![]Bar {
    // Need at least 'period' data points to calculate the first SMA
    if (data.len < period) {
        // Return empty slice if not enough data, maybe error is better?
        // return error.InsufficientData;
        return alloc.alloc(Bar, 0) catch return error.OutOfMemory;
    }

    // ArrayList to store the results (Timestamp + SMA Value)
    var sma_results = std.ArrayList(Bar).init(alloc);
    errdefer sma_results.deinit(); // Ensure cleanup if append fails

    // Calculate the sum of the first 'period' closing prices
    var sum: f64 = 0;
    for (data[0..period]) |row| {
        sum += row.c;
    }

    // Calculate and store the first SMA value
    // The timestamp corresponds to the *end* of the first window
    const first_sma_value = sum / @as(f64, @floatFromInt(period));
    try sma_results.append(Bar{
        .ts = data[period - 1].ts, // TS of the last day in the window
        .o = 0, // o, h, l are not relevant for SMA, set to 0 or NaN
        .h = 0,
        .l = 0,
        .c = first_sma_value, // Store SMA in the 'close' field
    });

    // Calculate subsequent SMAs using a sliding window
    var i: usize = period;
    while (i < data.len) : (i += 1) {
        // Efficiently update the sum: subtract the oldest, add the newest
        sum -= data[i - period].c;
        sum += data[i].c;

        const sma_value = sum / @as(f64, @floatFromInt(period));

        try sma_results.append(Bar{
            .ts = data[i].ts, // TS of the current day
            .o = 0,
            .h = 0,
            .l = 0,
            .c = sma_value, // Store SMA in the 'close' field
        });
    }

    // Return the results as an owned slice
    return sma_results.toOwnedSlice();
}

// └────────────────────────────────────────────────────────────────────────────────┘

// ┌─────────────────────────── smaForDateRange (Public API) ───────────────────────┐

/// Fetches data for a given date range and calculates the Simple Moving Average (SMA).
/// `from_str`, `to_str`: Date strings in "YYYY-MM-DD" format.
/// `period`: The number of data points (days) for the SMA window.
/// `ds`: The DataSet to fetch from (e.g., .btc_usd).
/// `alloc`: Memory allocator.
/// Returns: A slice of `Bar` where `ts` is the timestamp and `c` is the SMA value,
///          or an error (fetch/parse error, insufficient data, out of memory).
pub fn smaForDateRange(
    from_str: []const u8,
    to_str: []const u8,
    period: u32,
    ds: DataSet,
    alloc: std.mem.Allocator,
) MAError![]Bar {
    // 1. Fetch the data for the specified date range
    const rows_in_range = try date_util.getRowsFromDates(from_str, to_str, ds, alloc);
    // IMPORTANT: Ensure the fetched data is freed when this function returns
    defer alloc.free(rows_in_range);

    // Basic check: If period is 0 or invalid, or larger than fetched data
    if (period == 0) {
        // Or perhaps return a specific error?
        return alloc.alloc(Bar, 0) catch return error.OutOfMemory;
    }

    // 2. Calculate the SMA on the fetched data
    // Pass the allocator again for the result slice
    const sma_values = try calculateSMA(period, rows_in_range, alloc);

    return sma_values;
}

// └────────────────────────────────────────────────────────────────────────────────┘
