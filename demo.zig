// ╔═══════════════════════════════════ OHLCV Demo Application ════════════════════════════════════╗

const std = @import("std");
const ohlcv = @import("lib/ohlcv.zig");

/// Demo configuration
const Config = struct {
    str_from_date: []const u8 = "2023-01-01",
    str_to_date: []const u8 = "2023-12-31",
    u32_sma_period: u32 = 200,
    u32_ema_period: u32 = 12,
    u32_rsi_period: u32 = 14,
};

/// Run analysis on a dataset
fn runAnalysis(allocator: std.mem.Allocator, writer: anytype, dataset: ohlcv.PresetSource, config: Config) !void {
    try writer.print("\n══════════════════════════════════════════\n", .{});
    try writer.print("Analyzing {s} from {s} to {s}\n", .{
        @tagName(dataset),
        config.str_from_date,
        config.str_to_date,
    });
    try writer.print("══════════════════════════════════════════\n\n", .{});

    // Fetch and parse data
    try writer.print("Fetching data...\n", .{});
    var series = try ohlcv.fetchPreset(dataset, allocator);
    defer series.deinit();

    try writer.print("Total rows: {d}\n", .{series.len()});

    // Filter by date range
    const from_ts = try parseDate(config.str_from_date);
    const to_ts = try parseDate(config.str_to_date);

    var filtered = try series.sliceByTime(from_ts, to_ts);
    defer filtered.deinit();

    try writer.print("Rows in date range: {d}\n\n", .{filtered.len()});

    // Calculate indicators
    try calculateAndPrintSMA(&filtered, allocator, writer, config.u32_sma_period);
    try calculateAndPrintEMA(&filtered, allocator, writer, config.u32_ema_period);
    try calculateAndPrintRSI(&filtered, allocator, writer, config.u32_rsi_period);
}

/// Calculate and print SMA results
fn calculateAndPrintSMA(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const sma = ohlcv.SmaIndicator{ .u32_period = period };

    var result = sma.calculate(series.*, allocator) catch |err| {
        try writer.print("SMA({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("SMA({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print EMA results
fn calculateAndPrintEMA(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const ema = ohlcv.EmaIndicator{ .u32_period = period };

    var result = ema.calculate(series.*, allocator) catch |err| {
        try writer.print("EMA({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("EMA({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print RSI results
fn calculateAndPrintRSI(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const rsi = ohlcv.RsiIndicator{ .u32_period = period };

    var result = rsi.calculate(series.*, allocator) catch |err| {
        try writer.print("RSI({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("RSI({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Print last N values from indicator result
fn printLastValues(result: *const ohlcv.IndicatorResult, writer: anytype, n: usize) !void {
    const start = if (result.len() > n) result.len() - n else 0;
    const end = result.len();

    try writer.print("Timestamp         | Value\n", .{});
    try writer.print("──────────────────┼────────\n", .{});

    var i = start;
    while (i < end) : (i += 1) {
        try writer.print("{d:17} │ {d:.2}\n", .{
            result.arr_timestamps[i],
            result.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Parse date string to Unix timestamp
fn parseDate(date_str: []const u8) !u64 {
    if (date_str.len != 10 or date_str[4] != '-' or date_str[7] != '-') {
        return error.InvalidDateFormat;
    }

    const year = try std.fmt.parseInt(u16, date_str[0..4], 10);
    const month = try std.fmt.parseInt(u8, date_str[5..7], 10);
    const day = try std.fmt.parseInt(u8, date_str[8..10], 10);

    // Simple date to timestamp conversion
    var days: u64 = 0;

    // Add years
    var y: u16 = 1970;
    while (y < year) : (y += 1) {
        days += if (isLeapYear(y)) 366 else 365;
    }

    // Add months
    const days_in_month = [_]u8{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var m: u8 = 1;
    while (m < month) : (m += 1) {
        days += days_in_month[m];
        if (m == 2 and isLeapYear(year)) days += 1;
    }

    // Add days
    days += day - 1;

    return days * 24 * 60 * 60;
}

fn isLeapYear(year: u16) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout_writer = std.io.getStdOut().writer();

    try stdout_writer.print("╔══════════════════════════════════════════╗\n", .{});
    try stdout_writer.print("║        OHLCV Library Demo v2.0           ║\n", .{});
    try stdout_writer.print("╚══════════════════════════════════════════╝\n", .{});

    const config = Config{};

    // Analyze multiple datasets
    const datasets = [_]ohlcv.PresetSource{ .btc_usd, .sp500 };

    for (datasets) |dataset| {
        try runAnalysis(allocator, stdout_writer, dataset, config);
    }

    // Demonstrate custom data source
    try stdout_writer.print("\n══════════════════════════════════════════\n", .{});
    try stdout_writer.print("Custom Data Source Example\n", .{});
    try stdout_writer.print("══════════════════════════════════════════\n\n", .{});

    const sample_csv =
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,105.0,115.0,100.0,112.0,1200000
        \\2024-01-03,112.0,120.0,108.0,115.0,1100000
        \\2024-01-04,115.0,118.0,110.0,113.0,900000
        \\2024-01-05,113.0,117.0,111.0,116.0,1050000
    ;

    var memory_source = try ohlcv.MemoryDataSource.init(allocator, sample_csv, false);
    defer memory_source.dataSource().deinit();

    const data = try memory_source.dataSource().fetch(allocator);
    defer allocator.free(data);

    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var custom_series = try parser.parse(data);
    defer custom_series.deinit();

    try stdout_writer.print("Parsed {d} rows from custom data\n", .{custom_series.len()});
    try stdout_writer.print("First row: timestamp={d}, close={d:.2}\n", .{
        custom_series.arr_rows[0].u64_timestamp,
        custom_series.arr_rows[0].f64_close,
    });
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
