// ╔═════════════════════════════════════ OHLCV Library v2.0 ══════════════════════════════════════╗

const std = @import("std");

// ┌───────────────────────────────────────── Core Types ──────────────────────────────────────────┐

pub const OhlcvRow = @import("types/ohlcv_row.zig").OhlcvRow;
pub const OhlcBar = @import("types/ohlc_bar.zig").OhlcBar;

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────────────────── Data Sources ─────────────────────────────────────────┐

pub const DataSource = @import("data_source/data_source.zig").DataSource;
pub const HttpDataSource = @import("data_source/http_data_source.zig").HttpDataSource;
pub const FileDataSource = @import("data_source/file_data_source.zig").FileDataSource;
pub const MemoryDataSource = @import("data_source/memory_data_source.zig").MemoryDataSource;

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌───────────────────────────────────────── Time Series ─────────────────────────────────────────┐

pub const TimeSeries = @import("time_series.zig").TimeSeries;

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌─────────────────────────────────────────── Parser ────────────────────────────────────────────┐

pub const CsvParser = @import("parser/csv_parser.zig").CsvParser;
pub const ParseError = @import("parser/csv_parser.zig").ParseError;

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌───────────────────────────────────────── Indicators ──────────────────────────────────────────┐

pub const IndicatorResult = @import("indicators/indicator_result.zig").IndicatorResult;
pub const SmaIndicator = @import("indicators/sma_indicator.zig").SmaIndicator;
pub const EmaIndicator = @import("indicators/ema_indicator.zig").EmaIndicator;
pub const RsiIndicator = @import("indicators/rsi_indicator.zig").RsiIndicator;
pub const BollingerBandsIndicator = @import("indicators/bollinger_bands_indicator.zig").BollingerBandsIndicator;
pub const MacdIndicator = @import("indicators/macd_indicator.zig").MacdIndicator;
pub const AtrIndicator = @import("indicators/atr_indicator.zig").AtrIndicator;
pub const StochasticIndicator = @import("indicators/stochastic_indicator.zig").StochasticIndicator;
pub const WmaIndicator = @import("indicators/wma_indicator.zig").WmaIndicator;
pub const RocIndicator = @import("indicators/roc_indicator.zig").RocIndicator;
pub const MomentumIndicator = @import("indicators/momentum_indicator.zig").MomentumIndicator;
pub const WilliamsRIndicator = @import("indicators/williams_r_indicator.zig").WilliamsRIndicator;
pub const VwapIndicator = @import("indicators/vwap_indicator.zig").VwapIndicator;
pub const CciIndicator = @import("indicators/cci_indicator.zig").CciIndicator;
pub const ObvIndicator = @import("indicators/obv_indicator.zig").ObvIndicator;
pub const DonchianChannelsIndicator = @import("indicators/donchian_channels_indicator.zig").DonchianChannelsIndicator;
pub const AroonIndicator = @import("indicators/aroon_indicator.zig").AroonIndicator;

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────────────── Convenience Functions ────────────────────────────────────┐

/// Quick fetch and parse from predefined sources
pub const PresetSource = enum { btc_usd, sp500, eth_usd, gold_usd };

pub fn fetchPreset(source: PresetSource, allocator: std.mem.Allocator) !TimeSeries {
    const url = switch (source) {
        .btc_usd => "https://raw.githubusercontent.com/Mario-SO/ohlcv/refs/heads/main/data/btc.csv",
        .sp500 => "https://raw.githubusercontent.com/Mario-SO/ohlcv/refs/heads/main/data/sp500.csv",
        .eth_usd => "https://raw.githubusercontent.com/Mario-SO/ohlcv/refs/heads/main/data/eth.csv",
        .gold_usd => "https://raw.githubusercontent.com/Mario-SO/ohlcv/refs/heads/main/data/gold.csv",
    };

    var http_source = try HttpDataSource.init(allocator, url);
    defer http_source.dataSource().deinit();

    const data = try http_source.dataSource().fetch(allocator);
    defer allocator.free(data);

    const parser = CsvParser{ .allocator = allocator };
    return try parser.parse(data);
}

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
