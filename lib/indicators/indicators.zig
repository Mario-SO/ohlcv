const std = @import("std");
const Allocator = std.mem.Allocator;
const Row = @import("../types/row.zig").Row;
const Bar = @import("../types/bar.zig").Bar;
const date_util = @import("../util/date.zig");
const provider = @import("../provider/provider.zig");
const DataSet = provider.DataSet;
const FetchError = @import("../types/errors.zig").FetchError;

// --- Indicator Imports (Keep these separate for clarity) ---
pub const sma = @import("sma.zig");
pub const ema = @import("ema.zig");
pub const rsi = @import("rsi.zig");

// --- Indicator Errors ---
// Combine errors from fetching, date parsing, filtering, and specific indicator calculations
// Add errors from new indicators here
pub const IndicatorError = FetchError || date_util.DateError || date_util.FilterError || sma.SMAError || ema.EMAError || rsi.RSIError;

// --- SMA Re-exports & Convenience Function ---
pub const calculateSMA = sma.calculateSMA;
pub const SmaOptions = sma.SmaOptions;
pub const SMAError = sma.SMAError;

/// Convenience wrapper: Fetches data, filters by date range, and calculates SMA.
pub fn calculateSMAForRange(
    from_str: []const u8,
    to_str: []const u8,
    options: SmaOptions,
    ds: DataSet,
    alloc: Allocator,
) IndicatorError![]Bar {
    const all_rows = try provider.fetch(ds, alloc);
    defer alloc.free(all_rows);
    const from_ts = try date_util.yyyymmddToUnix(from_str);
    const to_ts_inclusive = try date_util.yyyymmddToUnix(to_str);
    if (from_ts > to_ts_inclusive) return error.InvalidDateRange;
    const rows_in_range = try date_util.filterRowsByTimestamp(
        all_rows,
        from_ts,
        to_ts_inclusive,
        alloc,
    );
    defer alloc.free(rows_in_range);
    return calculateSMA(rows_in_range, options, alloc);
}

// --- EMA Re-exports & Convenience Function ---
pub const calculateEMA = ema.calculateEMA;
pub const EmaOptions = ema.EmaOptions;
pub const EMAError = ema.EMAError;

/// Convenience wrapper: Fetches data, filters by date range, and calculates EMA.
pub fn calculateEMAForRange(
    from_str: []const u8,
    to_str: []const u8,
    options: EmaOptions,
    ds: DataSet,
    alloc: Allocator,
) IndicatorError![]Bar {
    // 1. Fetch ALL data for the dataset
    const all_rows = try provider.fetch(ds, alloc);
    defer alloc.free(all_rows);

    // 2. Parse date strings to timestamps
    const from_ts = try date_util.yyyymmddToUnix(from_str);
    const to_ts_inclusive = try date_util.yyyymmddToUnix(to_str);

    // Basic check: ensure 'from' is not after 'to'.
    if (from_ts > to_ts_inclusive) return error.InvalidDateRange;

    // 3. Filter the fetched rows by the timestamp range
    const rows_in_range = try date_util.filterRowsByTimestamp(
        all_rows,
        from_ts,
        to_ts_inclusive,
        alloc,
    );
    // IMPORTANT: Free the filtered slice as well, since filterRowsByTimestamp allocates
    defer alloc.free(rows_in_range);

    // 4. Call the core calculation function with the filtered data
    return calculateEMA(rows_in_range, options, alloc);
}

// --- RSI Re-exports & Convenience Function ---
pub const calculateRSI = rsi.calculateRSI;
pub const RsiOptions = rsi.RsiOptions;
pub const RSIError = rsi.RSIError;

/// Convenience wrapper: Fetches data, filters by date range, and calculates RSI.
pub fn calculateRSIForRange(
    from_str: []const u8,
    to_str: []const u8,
    options: RsiOptions,
    ds: DataSet,
    alloc: Allocator,
) IndicatorError![]Bar {
    const all_rows = try provider.fetch(ds, alloc);
    defer alloc.free(all_rows);
    const from_ts = try date_util.yyyymmddToUnix(from_str);
    const to_ts_inclusive = try date_util.yyyymmddToUnix(to_str);
    if (from_ts > to_ts_inclusive) return error.InvalidDateRange;
    const rows_in_range = try date_util.filterRowsByTimestamp(
        all_rows,
        from_ts,
        to_ts_inclusive,
        alloc,
    );
    defer alloc.free(rows_in_range);
    return calculateRSI(rows_in_range, options, alloc);
}
