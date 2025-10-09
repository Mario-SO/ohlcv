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

pub const TimeSeries = @import("utils/time_series.zig").TimeSeries;

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────────────────── Memory Utils ─────────────────────────────────────────┐

pub const MemoryPool = @import("utils/memory_pool.zig").MemoryPool;
pub const IndicatorArena = @import("utils/memory_pool.zig").IndicatorArena;

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌───────────────────────────────────────────── Parser ──────────────────────────────────────────┐

pub const CsvParser = @import("parser/csv_parser.zig").CsvParser;
pub const StreamingCsvParser = @import("parser/streaming_csv_parser.zig").StreamingCsvParser;
pub const ParseError = @import("parser/csv_parser.zig").ParseError;

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌───────────────────────────────────────── Indicators ──────────────────────────────────────────┐

pub const IndicatorResult = @import("indicators/indicator_result.zig").IndicatorResult;

// Single-line indicators
pub const AccumulationDistributionIndicator = @import("indicators/accumulation_distribution_indicator.zig").AccumulationDistributionIndicator;
pub const AtrIndicator = @import("indicators/atr_indicator.zig").AtrIndicator;
pub const CciIndicator = @import("indicators/cci_indicator.zig").CciIndicator;
pub const CmfIndicator = @import("indicators/cmf_indicator.zig").CmfIndicator;
pub const EmaIndicator = @import("indicators/ema_indicator.zig").EmaIndicator;
pub const ForceIndexIndicator = @import("indicators/force_index_indicator.zig").ForceIndexIndicator;
pub const MfiIndicator = @import("indicators/mfi_indicator.zig").MfiIndicator;
pub const MomentumIndicator = @import("indicators/momentum_indicator.zig").MomentumIndicator;
pub const ObvIndicator = @import("indicators/obv_indicator.zig").ObvIndicator;
pub const ParabolicSarIndicator = @import("indicators/parabolic_sar_indicator.zig").ParabolicSarIndicator;
pub const RocIndicator = @import("indicators/roc_indicator.zig").RocIndicator;
pub const RsiIndicator = @import("indicators/rsi_indicator.zig").RsiIndicator;
pub const SmaIndicator = @import("indicators/sma_indicator.zig").SmaIndicator;
pub const StochasticRsiIndicator = @import("indicators/stochastic_rsi_indicator.zig").StochasticRsiIndicator;
pub const TrixIndicator = @import("indicators/trix_indicator.zig").TrixIndicator;
pub const UltimateOscillatorIndicator = @import("indicators/ultimate_oscillator_indicator.zig").UltimateOscillatorIndicator;
pub const VwapIndicator = @import("indicators/vwap_indicator.zig").VwapIndicator;
pub const WilliamsRIndicator = @import("indicators/williams_r_indicator.zig").WilliamsRIndicator;
pub const WmaIndicator = @import("indicators/wma_indicator.zig").WmaIndicator;
pub const ZigZagIndicator = @import("indicators/zig_zag_indicator.zig").ZigZagIndicator;

// Multi-line indicators
pub const AdxIndicator = @import("indicators/adx_indicator.zig").AdxIndicator;
pub const AroonIndicator = @import("indicators/aroon_indicator.zig").AroonIndicator;
pub const BollingerBandsIndicator = @import("indicators/bollinger_bands_indicator.zig").BollingerBandsIndicator;
pub const DmiIndicator = @import("indicators/dmi_indicator.zig").DmiIndicator;
pub const DonchianChannelsIndicator = @import("indicators/donchian_channels_indicator.zig").DonchianChannelsIndicator;
pub const ElderRayIndicator = @import("indicators/elder_ray_indicator.zig").ElderRayIndicator;
pub const HeikinAshiIndicator = @import("indicators/heikin_ashi_indicator.zig").HeikinAshiIndicator;
pub const IchimokuCloudIndicator = @import("indicators/ichimoku_cloud_indicator.zig").IchimokuCloudIndicator;
pub const KeltnerChannelsIndicator = @import("indicators/keltner_channels_indicator.zig").KeltnerChannelsIndicator;
pub const MacdIndicator = @import("indicators/macd_indicator.zig").MacdIndicator;
pub const PivotPointsIndicator = @import("indicators/pivot_points_indicator.zig").PivotPointsIndicator;
pub const PriceChannelsIndicator = @import("indicators/price_channels_indicator.zig").PriceChannelsIndicator;
pub const StochasticIndicator = @import("indicators/stochastic_indicator.zig").StochasticIndicator;

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
