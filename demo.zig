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
    u32_adx_period: u32 = 14,
    u32_mfi_period: u32 = 14,
    u32_cmf_period: u32 = 20,
    f64_sar_af: f64 = 0.02,
    u32_trix_period: u32 = 14,
    u32_force_index_period: u32 = 13,
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

    // Fetch and parse data from local file
    try writer.print("Loading data from local file...\n", .{});

    const file_path = switch (dataset) {
        .btc_usd => "data/btc.csv",
        .sp500 => "data/sp500.csv",
        .eth_usd => "data/eth.csv",
        .gold_usd => "data/gold.csv",
    };

    var file_source = try ohlcv.FileDataSource.init(allocator, file_path);
    defer file_source.dataSource().deinit();

    const data = try file_source.dataSource().fetch(allocator);
    defer allocator.free(data);

    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var series = try parser.parse(data);
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
    try calculateAndPrintADX(&filtered, allocator, writer, config.u32_adx_period);
    try calculateAndPrintMFI(&filtered, allocator, writer, config.u32_mfi_period);
    try calculateAndPrintCMF(&filtered, allocator, writer, config.u32_cmf_period);
    try calculateAndPrintParabolicSAR(&filtered, allocator, writer, config.f64_sar_af);
    try calculateAndPrintTRIX(&filtered, allocator, writer, config.u32_trix_period);
    try calculateAndPrintForceIndex(&filtered, allocator, writer, config.u32_force_index_period);

    // Additional indicators
    try calculateAndPrintAccumulationDistribution(&filtered, allocator, writer);
    try calculateAndPrintStochasticRSI(&filtered, allocator, writer, 14, 14);
    try calculateAndPrintUltimateOscillator(&filtered, allocator, writer);
    try calculateAndPrintKeltnerChannels(&filtered, allocator, writer, 20, 10);
    try calculateAndPrintPivotPoints(&filtered, allocator, writer);
    try calculateAndPrintPriceChannels(&filtered, allocator, writer, 20);
    try calculateAndPrintElderRay(&filtered, allocator, writer, 13);
    try calculateAndPrintZigZag(&filtered, allocator, writer, 5.0);

    // Complex indicators
    try writer.print("\n─── ADVANCED INDICATORS ───\n\n", .{});
    try calculateAndPrintDMI(&filtered, allocator, writer, 14);
    try calculateAndPrintIchimokuCloud(&filtered, allocator, writer);
    try calculateAndPrintHeikinAshi(&filtered, allocator, writer);
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

/// Calculate and print ADX results
fn calculateAndPrintADX(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const adx = ohlcv.AdxIndicator{ .u32_period = period };

    var result = adx.calculate(series.*, allocator) catch |err| {
        try writer.print("ADX({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("ADX({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});

    const len = result.adx.len();
    const start = if (len > 5) len - 5 else 0;

    try writer.print("Timestamp         | ADX       | +DI       | -DI\n", .{});
    try writer.print("──────────────────┼───────────┼───────────┼───────────\n", .{});

    var i = start;
    while (i < len) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2} │ {d:9.2}\n", .{
            result.adx.arr_timestamps[i],
            result.adx.arr_values[i],
            result.plus_di.arr_values[i],
            result.minus_di.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Calculate and print MFI results
fn calculateAndPrintMFI(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const mfi = ohlcv.MfiIndicator{ .u32_period = period };

    var result = mfi.calculate(series.*, allocator) catch |err| {
        try writer.print("MFI({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("MFI({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print CMF results
fn calculateAndPrintCMF(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const cmf = ohlcv.CmfIndicator{ .u32_period = period };

    var result = cmf.calculate(series.*, allocator) catch |err| {
        try writer.print("CMF({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("CMF({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Parabolic SAR results
fn calculateAndPrintParabolicSAR(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, initial_af: f64) !void {
    const sar = ohlcv.ParabolicSarIndicator{ .f64_initial_af = initial_af };

    var result = sar.calculate(series.*, allocator) catch |err| {
        try writer.print("Parabolic SAR Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Parabolic SAR Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print TRIX results
fn calculateAndPrintTRIX(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const trix = ohlcv.TrixIndicator{ .u32_period = period };

    var result = trix.calculate(series.*, allocator) catch |err| {
        try writer.print("TRIX({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("TRIX({d}) Results (basis points):\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Force Index results
fn calculateAndPrintForceIndex(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const force = ohlcv.ForceIndexIndicator{ .u32_period = period };

    var result = force.calculate(series.*, allocator) catch |err| {
        try writer.print("Force Index({d}) Error: {any}\n\n", .{ period, err });
        return;
    };
    defer result.deinit();

    try writer.print("Force Index({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Accumulation/Distribution Line
fn calculateAndPrintAccumulationDistribution(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype) !void {
    const ad = ohlcv.AccumulationDistributionIndicator{};

    var result = ad.calculate(series.*, allocator) catch |err| {
        try writer.print("A/D Line Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Accumulation/Distribution Line Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Stochastic RSI
fn calculateAndPrintStochasticRSI(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, rsi_period: u32, stoch_period: u32) !void {
    const stoch_rsi = ohlcv.StochasticRsiIndicator{ 
        .u32_rsi_period = rsi_period,
        .u32_stochastic_period = stoch_period,
    };

    var result = stoch_rsi.calculate(series.*, allocator) catch |err| {
        try writer.print("Stochastic RSI Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Stochastic RSI Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Ultimate Oscillator
fn calculateAndPrintUltimateOscillator(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype) !void {
    const uo = ohlcv.UltimateOscillatorIndicator{};

    var result = uo.calculate(series.*, allocator) catch |err| {
        try writer.print("Ultimate Oscillator Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Ultimate Oscillator Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    try printLastValues(&result, writer, 5);
}

/// Calculate and print Keltner Channels
fn calculateAndPrintKeltnerChannels(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, ema_period: u32, atr_period: u32) !void {
    const kc = ohlcv.KeltnerChannelsIndicator{ 
        .u32_ema_period = ema_period,
        .u32_atr_period = atr_period,
    };

    var result = kc.calculate(series.*, allocator) catch |err| {
        try writer.print("Keltner Channels Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Keltner Channels Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    
    const len = result.middle_line.len();
    const start = if (len > 5) len - 5 else 0;
    
    try writer.print("Timestamp         | Upper     | Middle    | Lower\n", .{});
    try writer.print("──────────────────┼───────────┼───────────┼───────────\n", .{});
    
    var i = start;
    while (i < len) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2} │ {d:9.2}\n", .{
            result.middle_line.arr_timestamps[i],
            result.upper_channel.arr_values[i],
            result.middle_line.arr_values[i],
            result.lower_channel.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Calculate and print Pivot Points
fn calculateAndPrintPivotPoints(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype) !void {
    const pp = ohlcv.PivotPointsIndicator{};

    var result = pp.calculate(series.*, allocator) catch |err| {
        try writer.print("Pivot Points Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Pivot Points Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    
    const len = result.pivot_point.len();
    const start = if (len > 5) len - 5 else 0;
    
    try writer.print("Timestamp         | Pivot     | R1        | R2        | S1        | S2\n", .{});
    try writer.print("──────────────────┼───────────┼───────────┼───────────┼───────────┼───────────\n", .{});
    
    var i = start;
    while (i < len) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2} │ {d:9.2} │ {d:9.2} │ {d:9.2}\n", .{
            result.pivot_point.arr_timestamps[i],
            result.pivot_point.arr_values[i],
            result.resistance_1.arr_values[i],
            result.resistance_2.arr_values[i],
            result.support_1.arr_values[i],
            result.support_2.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Calculate and print Price Channels
fn calculateAndPrintPriceChannels(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const pc = ohlcv.PriceChannelsIndicator{ .u32_period = period };

    var result = pc.calculate(series.*, allocator) catch |err| {
        try writer.print("Price Channels Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Price Channels({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    
    const len = result.middle_channel.len();
    const start = if (len > 5) len - 5 else 0;
    
    try writer.print("Timestamp         | Upper     | Middle    | Lower\n", .{});
    try writer.print("──────────────────┼───────────┼───────────┼───────────\n", .{});
    
    var i = start;
    while (i < len) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2} │ {d:9.2}\n", .{
            result.middle_channel.arr_timestamps[i],
            result.upper_channel.arr_values[i],
            result.middle_channel.arr_values[i],
            result.lower_channel.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Calculate and print Elder Ray
fn calculateAndPrintElderRay(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const elder = ohlcv.ElderRayIndicator{ .u32_period = period };

    var result = elder.calculate(series.*, allocator) catch |err| {
        try writer.print("Elder Ray Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Elder Ray({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    
    const len = result.bull_power.len();
    const start = if (len > 5) len - 5 else 0;
    
    try writer.print("Timestamp         | Bull Power | Bear Power\n", .{});
    try writer.print("──────────────────┼────────────┼────────────\n", .{});
    
    var i = start;
    while (i < len) : (i += 1) {
        try writer.print("{d:17} │ {d:10.2} │ {d:10.2}\n", .{
            result.bull_power.arr_timestamps[i],
            result.bull_power.arr_values[i],
            result.bear_power.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Calculate and print Zig Zag
fn calculateAndPrintZigZag(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, threshold: f64) !void {
    const zz = ohlcv.ZigZagIndicator{ .f64_threshold = threshold };

    var result = zz.calculate(series.*, allocator) catch |err| {
        try writer.print("Zig Zag Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Zig Zag({d}%) Results (reversal points only):\n", .{threshold});
    try writer.print("─────────────────────────────────\n", .{});
    
    // Only show non-NaN values
    var count: usize = 0;
    for (result.arr_values, result.arr_timestamps) |value, timestamp| {
        if (!std.math.isNan(value)) {
            try writer.print("{d:17} │ {d:.2}\n", .{ timestamp, value });
            count += 1;
            if (count >= 10) break; // Show up to 10 reversal points
        }
    }
    try writer.print("\n", .{});
}

/// Calculate and print DMI
fn calculateAndPrintDMI(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype, period: u32) !void {
    const dmi = ohlcv.DmiIndicator{ .u32_period = period };

    var result = dmi.calculate(series.*, allocator) catch |err| {
        try writer.print("DMI Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("DMI({d}) Results:\n", .{period});
    try writer.print("─────────────────────────────────\n", .{});
    
    const len = result.adx.len();
    const start = if (len > 5) len - 5 else 0;
    
    try writer.print("Timestamp         | +DI       | -DI       | ADX\n", .{});
    try writer.print("──────────────────┼───────────┼───────────┼───────────\n", .{});
    
    var i = start;
    while (i < len) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2} │ {d:9.2}\n", .{
            result.adx.arr_timestamps[i],
            result.plus_di.arr_values[i],
            result.minus_di.arr_values[i],
            result.adx.arr_values[i],
        });
    }
    try writer.print("\n", .{});
}

/// Calculate and print Ichimoku Cloud
fn calculateAndPrintIchimokuCloud(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype) !void {
    const ichimoku = ohlcv.IchimokuCloudIndicator{};

    var result = ichimoku.calculate(series.*, allocator) catch |err| {
        try writer.print("Ichimoku Cloud Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Ichimoku Cloud Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    
    // Show last 3 values for each component
    const len = result.tenkan_sen.len();
    const start = if (len > 3) len - 3 else 0;
    
    try writer.print("Component | ", .{});
    var i = start;
    while (i < len) : (i += 1) {
        try writer.print("TS {d:10} | ", .{result.tenkan_sen.arr_timestamps[i]});
    }
    try writer.print("\n", .{});
    try writer.print("──────────┼", .{});
    i = start;
    while (i < len) : (i += 1) {
        try writer.print("───────────────┼", .{});
    }
    try writer.print("\n", .{});
    
    // Tenkan-sen
    try writer.print("Tenkan    │ ", .{});
    i = start;
    while (i < len) : (i += 1) {
        try writer.print("{d:13.2} │ ", .{result.tenkan_sen.arr_values[i]});
    }
    try writer.print("\n", .{});
    
    // Kijun-sen
    try writer.print("Kijun     │ ", .{});
    i = start;
    while (i < len) : (i += 1) {
        if (i < result.kijun_sen.len()) {
            try writer.print("{d:13.2} │ ", .{result.kijun_sen.arr_values[i]});
        } else {
            try writer.print("             - │ ", .{});
        }
    }
    try writer.print("\n", .{});
    
    try writer.print("\n", .{});
}

/// Calculate and print Heikin Ashi
fn calculateAndPrintHeikinAshi(series: *ohlcv.TimeSeries, allocator: std.mem.Allocator, writer: anytype) !void {
    const ha = ohlcv.HeikinAshiIndicator{};

    var result = ha.calculate(series.*, allocator) catch |err| {
        try writer.print("Heikin Ashi Error: {any}\n\n", .{err});
        return;
    };
    defer result.deinit();

    try writer.print("Heikin Ashi Candles Results:\n", .{});
    try writer.print("─────────────────────────────────\n", .{});
    
    const len = result.ha_open.len();
    const start = if (len > 5) len - 5 else 0;
    
    try writer.print("Timestamp         | HA-Open   | HA-High   | HA-Low    | HA-Close\n", .{});
    try writer.print("──────────────────┼───────────┼───────────┼───────────┼───────────\n", .{});
    
    var i = start;
    while (i < len) : (i += 1) {
        try writer.print("{d:17} │ {d:9.2} │ {d:9.2} │ {d:9.2} │ {d:9.2}\n", .{
            result.ha_open.arr_timestamps[i],
            result.ha_open.arr_values[i],
            result.ha_high.arr_values[i],
            result.ha_low.arr_values[i],
            result.ha_close.arr_values[i],
        });
    }
    try writer.print("\n", .{});
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
        runAnalysis(allocator, stdout_writer, dataset, config) catch |err| {
            // Handle broken pipe gracefully (common in CI when piping to head)
            if (err == error.BrokenPipe) {
                return;
            }
            return err;
        };
    }

    // Demonstrate custom data source
    stdout_writer.print("\n══════════════════════════════════════════\n", .{}) catch |err| {
        if (err == error.BrokenPipe) return;
        return err;
    };
    stdout_writer.print("Custom Data Source Example\n", .{}) catch |err| {
        if (err == error.BrokenPipe) return;
        return err;
    };
    stdout_writer.print("══════════════════════════════════════════\n\n", .{}) catch |err| {
        if (err == error.BrokenPipe) return;
        return err;
    };

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

    stdout_writer.print("Parsed {d} rows from custom data\n", .{custom_series.len()}) catch |err| {
        if (err == error.BrokenPipe) return;
        return err;
    };
    stdout_writer.print("First row: timestamp={d}, close={d:.2}\n", .{
        custom_series.arr_rows[0].u64_timestamp,
        custom_series.arr_rows[0].f64_close,
    }) catch |err| {
        if (err == error.BrokenPipe) return;
        return err;
    };
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
