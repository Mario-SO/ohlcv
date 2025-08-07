// ╔═══════════════════════════════════ OHLCV Demo Application ════════════════════════════════════╗

const std = @import("std");
const ohlcv = @import("lib/ohlcv.zig");
const date = @import("lib/utils/date.zig");

/// Demo configuration
const Config = struct {
    str_from_date: []const u8 = "2023-01-01",
    str_to_date: []const u8 = "2023-12-31",
    u32_sma_period: u32 = 200,
    u32_ema_period: u32 = 12,
    u32_rsi_period: u32 = 14,
    u32_bb_period: u32 = 20,
    u32_atr_period: u32 = 14,
    u32_stoch_k_period: u32 = 14,
    u32_wma_period: u32 = 20,
    u32_roc_period: u32 = 12,
    u32_momentum_period: u32 = 10,
    u32_williams_r_period: u32 = 14,
    u32_cci_period: u32 = 20,
    u32_donchian_period: u32 = 20,
    u32_aroon_period: u32 = 25,
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
    const from_ts = try date.parseDateYmd(config.str_from_date);
    const to_ts = try date.parseDateYmd(config.str_to_date);

    var filtered = try series.sliceByTime(from_ts, to_ts);
    defer filtered.deinit();

    try writer.print("Rows in date range: {d}\n\n", .{filtered.len()});

    // Calculate indicators
    try calculateAndPrintSMA(&filtered, allocator, writer, config.u32_sma_period);
    try calculateAndPrintEMA(&filtered, allocator, writer, config.u32_ema_period);
    try calculateAndPrintRSI(&filtered, allocator, writer, config.u32_rsi_period);
    try calculateAndPrintBollingerBands(&filtered, allocator, writer, config.u32_bb_period);
    try calculateAndPrintMACD(&filtered, allocator, writer);
    try calculateAndPrintATR(&filtered, allocator, writer, config.u32_atr_period);
    try calculateAndPrintStochastic(&filtered, allocator, writer, config.u32_stoch_k_period);
    try calculateAndPrintWMA(&filtered, allocator, writer, config.u32_wma_period);
    try calculateAndPrintROC(&filtered, allocator, writer, config.u32_roc_period);
    try calculateAndPrintMomentum(&filtered, allocator, writer, config.u32_momentum_period);
    try calculateAndPrintWilliamsR(&filtered, allocator, writer, config.u32_williams_r_period);
    try calculateAndPrintVWAP(&filtered, allocator, writer);
    try calculateAndPrintCCI(&filtered, allocator, writer, config.u32_cci_period);
    try calculateAndPrintOBV(&filtered, allocator, writer);
    try calculateAndPrintDonchian(&filtered, allocator, writer, config.u32_donchian_period);
    try calculateAndPrintAroon(&filtered, allocator, writer, config.u32_aroon_period);
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

/// Calculate and print Bollinger Bands results
fn calculateAndPrintBollingerBands(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const bb = ohlcv.BollingerBandsIndicator{ .u32_period = period };

    var result = bb.calculate(series.*, allocator) catch |err| {
        try writer.print("Bollinger Bands({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("Bollinger Bands({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printBollingerBands(&result, writer, 5);
}

/// Calculate and print MACD results
fn calculateAndPrintMACD(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype) !void {
    const macd = ohlcv.MacdIndicator{};

    var result = macd.calculate(series.*, allocator) catch |err| {
        try writer.print("MACD Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("MACD(12,26,9) Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    try printMACD(&result, writer, 5);
}

/// Calculate and print ATR results
fn calculateAndPrintATR(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const atr = ohlcv.AtrIndicator{ .u32_period = period };

    var result = atr.calculate(series.*, allocator) catch |err| {
        try writer.print("ATR({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("ATR({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Stochastic results
fn calculateAndPrintStochastic(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, k_period: u32) !void {
    const stoch = ohlcv.StochasticIndicator{ .u32_k_period = k_period };

    var result = stoch.calculate(series.*, allocator) catch |err| {
        try writer.print("Stochastic({d},1,3) Error: {any}\n\n", .{ k_period, err });
        return;
    };
    defer result.deinit();

    try writer.print("Stochastic({d},1,3) Results:\n", .{k_period});
    try writer.print("─────────────────────────────────\n", .{});
    try printStochastic(&result, writer, 5);
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

/// Print Bollinger Bands values
fn printBollingerBands(result: *const ohlcv.BollingerBandsIndicator.BollingerBandsResult, writer: anytype, n: usize) !void {
    const len = result.middle_band.len();
    const start = if (len > n) len - n else 0;
    const end = len;

    try writer.print("Timestamp         | Upper     | Middle    | Lower\n", .{});
    try writer.print("──────────────────┼───────────┼───────────┼───────────\n", .{});

    var i = start;
    while (i < end) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2} │ {d:9.2}\n", .{
            result.middle_band.arr_timestamps[i],
            result.upper_band.arr_values[i],
            result.middle_band.arr_values[i],
            result.lower_band.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Print Donchian Channels values
fn printDonchian(result: *const ohlcv.DonchianChannelsIndicator.DonchianResult, writer: anytype, n: usize) !void {
    const len = result.middle_band.len();
    const start = if (len > n) len - n else 0;
    const end = len;

    try writer.print("Timestamp         | Upper     | Middle    | Lower\n", .{});
    try writer.print("──────────────────┼───────────┼───────────┼───────────\n", .{});

    var i = start;
    while (i < end) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2} │ {d:9.2}\n", .{
            result.middle_band.arr_timestamps[i],
            result.upper_band.arr_values[i],
            result.middle_band.arr_values[i],
            result.lower_band.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Print MACD values
fn printMACD(result: *const ohlcv.MacdIndicator.MacdResult, writer: anytype, n: usize) !void {
    const len = result.macd_line.len();
    const start = if (len > n) len - n else 0;
    const end = len;

    try writer.print("Timestamp         | MACD      | Signal    | Histogram\n", .{});
    try writer.print("──────────────────┼───────────┼───────────┼───────────\n", .{});

    var i = start;
    while (i < end) : (i += 1) {
        try writer.print("{d:17} │ {d:9.4} │ {d:9.4} │ {d:9.4}\n", .{
            result.macd_line.arr_timestamps[i],
            result.macd_line.arr_values[i],
            result.signal_line.arr_values[i],
            result.histogram.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Print Stochastic values
fn printStochastic(result: *const ohlcv.StochasticIndicator.StochasticResult, writer: anytype, n: usize) !void {
    const len = result.k_percent.len();
    const start = if (len > n) len - n else 0;
    const end = len;

    try writer.print("Timestamp         | %K        | %D\n", .{});
    try writer.print("──────────────────┼───────────┼───────────\n", .{});

    var i = start;
    while (i < end) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2}\n", .{
            result.k_percent.arr_timestamps[i],
            result.k_percent.arr_values[i],
            result.d_percent.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Print Aroon values
fn printAroon(result: *const ohlcv.AroonIndicator.AroonResult, writer: anytype, n: usize) !void {
    const len = result.aroon_up.len();
    const start = if (len > n) len - n else 0;
    const end = len;

    try writer.print("Timestamp         | Aroon Up  | Aroon Down\n", .{});
    try writer.print("──────────────────┼───────────┼───────────\n", .{});

    var i = start;
    while (i < end) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2}\n", .{
            result.aroon_up.arr_timestamps[i],
            result.aroon_up.arr_values[i],
            result.aroon_down.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Calculate and print WMA results
fn calculateAndPrintWMA(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const wma = ohlcv.WmaIndicator{ .u32_period = period };

    var result = wma.calculate(series.*, allocator) catch |err| {
        try writer.print("WMA({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("WMA({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print ROC results
fn calculateAndPrintROC(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const roc = ohlcv.RocIndicator{ .u32_period = period };

    var result = roc.calculate(series.*, allocator) catch |err| {
        try writer.print("ROC({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("ROC({d}) Results (%):\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Momentum results
fn calculateAndPrintMomentum(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const momentum = ohlcv.MomentumIndicator{ .u32_period = period };

    var result = momentum.calculate(series.*, allocator) catch |err| {
        try writer.print("Momentum({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("Momentum({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Williams %R results
fn calculateAndPrintWilliamsR(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const williams_r = ohlcv.WilliamsRIndicator{ .u32_period = period };

    var result = williams_r.calculate(series.*, allocator) catch |err| {
        try writer.print("Williams %R({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("Williams %R({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print VWAP results
fn calculateAndPrintVWAP(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype) !void {
    const vwap = ohlcv.VwapIndicator{};

    var result = vwap.calculate(series.*, allocator) catch |err| {
        try writer.print("VWAP Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("VWAP Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print CCI results
fn calculateAndPrintCCI(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const cci = ohlcv.CciIndicator{ .u32_period = period };

    var result = cci.calculate(series.*, allocator) catch |err| {
        try writer.print("CCI({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("CCI({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print OBV results
fn calculateAndPrintOBV(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype) !void {
    const obv = ohlcv.ObvIndicator{};

    var result = obv.calculate(series.*, allocator) catch |err| {
        try writer.print("OBV Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("OBV Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Donchian Channels results
fn calculateAndPrintDonchian(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const don = ohlcv.DonchianChannelsIndicator{ .u32_period = period };

    var result = don.calculate(series.*, allocator) catch |err| {
        try writer.print("Donchian({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("Donchian Channels({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printDonchian(&result, writer, 5);
}

/// Calculate and print Aroon results
fn calculateAndPrintAroon(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const aroon = ohlcv.AroonIndicator{ .u32_period = period };

    var result = aroon.calculate(series.*, allocator) catch |err| {
        try writer.print("Aroon({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("Aroon({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printAroon(&result, writer, 5);
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
