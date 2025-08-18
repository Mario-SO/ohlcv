# OHLCV Library Architecture v3.0

## Overview

The OHLCV library has been enhanced with high-performance parsing and memory management capabilities. Key improvements include:

- **Decoupled data sources** - Easy to add custom data providers
- **Efficient time series container** - Zero-copy operations where possible
- **Clean indicator framework** - Consistent API across all 37 indicators
- **Hungarian notation** - Clear type information in variable names
- **Performance optimizations** - Pre-allocation, SIMD-ready structures
- **Streaming parser** - Process large datasets without full memory load
- **Memory pooling** - Efficient allocation reuse for hot paths
- **Fast parsing primitives** - Optimized line counting and parsing

## Naming Conventions

```zig
// Variables: snake_case with type prefix
u64_timestamp   // unsigned 64-bit
f64_price       // 64-bit float
b_is_valid      // boolean
str_name        // string
arr_values      // array

// Functions: camelCase
calculateSMA()
parseDate()
fetchData()

// Structures: PascalCase
TimeSeries
OhlcvRow
SmaIndicator
```

## Core Components

### 1. Data Types

```zig
// ╔══════════════════════════════════════ Core Types ══════════════════════════════════════╗
OhlcvRow - Full OHLCV data with volume
OhlcBar  - OHLC data without volume (for indicators)
// ╚════════════════════════════════════════════════════════════════════════════════════════╝
```

### 2. Data Sources

```zig
// ╔══════════════════════════════════════ Data Sources ══════════════════════════════════════╗
DataSource       - Interface for all data sources
HttpDataSource   - Fetch from HTTP/HTTPS endpoints
FileDataSource   - Read from local files
MemoryDataSource - Use in-memory data
// ╚══════════════════════════════════════════════════════════════════════════════════════════╝
```

### 3. Parsers

```zig
// ╔══════════════════════════════════════ Parsers ══════════════════════════════════════╗
CsvParser           - Standard CSV parser with robust error handling
StreamingCsvParser  - Process large files in chunks
fast_parser         - Optimized parsing primitives (internal)
// ╚═════════════════════════════════════════════════════════════════════════════════════╝
```

### 4. Memory Management

```zig
// ╔══════════════════════════════════════ Memory ══════════════════════════════════════╗
MemoryPool      - Reusable memory allocation pool
IndicatorArena  - Arena allocator for batch calculations
// ╚═════════════════════════════════════════════════════════════════════════════════════╝
```

### 5. Time Series Container

```zig
// ╔══════════════════════════════════════ Time Series ══════════════════════════════════════╗
TimeSeries - Efficient container with:
  - Zero-copy slicing by time
  - Filter operations
  - Iterator support
  - Map transformations
// ╚═════════════════════════════════════════════════════════════════════════════════════════╝
```

### 6. Indicators (37 Total)

```zig
// ╔══════════════════════════════════════ Indicators ══════════════════════════════════════╗

// Single-line indicators (return IndicatorResult):
AccumulationDistributionIndicator - A/D Line measuring supply and demand
AtrIndicator - Average True Range (volatility)
CciIndicator - Commodity Channel Index
CmfIndicator - Chaikin Money Flow
EmaIndicator - Exponential Moving Average  
ForceIndexIndicator - Force Index (price and volume)
MfiIndicator - Money Flow Index (volume-weighted RSI)
MomentumIndicator - Price Momentum
ObvIndicator - On-Balance Volume (cumulative)
ParabolicSarIndicator - Parabolic SAR (trailing stop)
RocIndicator - Rate of Change
RsiIndicator - Relative Strength Index
SmaIndicator - Simple Moving Average
StochasticRsiIndicator - Stochastic applied to RSI
TrixIndicator - Triple Exponential Average oscillator
UltimateOscillatorIndicator - Combines multiple timeframes
VwapIndicator - Volume Weighted Average Price
WilliamsRIndicator - Williams %R
WmaIndicator - Weighted Moving Average
ZigZagIndicator - Filters minor price movements

// Multi-line indicators (return specialized structures):
AdxIndicator - ADX with +DI and -DI (AdxResult)
AroonIndicator - Aroon Up/Down (AroonResult)
BollingerBandsIndicator - Upper/middle/lower bands (BollingerBandsResult)
DmiIndicator - Full DMI system (DmiResult)
DonchianChannelsIndicator - Channel bands (DonchianResult)
ElderRayIndicator - Bull and bear power (ElderRayResult)
HeikinAshiIndicator - Smoothed candles (HeikinAshiResult)
IchimokuCloudIndicator - 5-component system (IchimokuCloudResult)
KeltnerChannelsIndicator - ATR-based channels (KeltnerChannelsResult)
MacdIndicator - MACD line, signal, histogram (MacdResult)
PivotPointsIndicator - Support/resistance levels (PivotPointsResult)
PriceChannelsIndicator - High/low channels (PriceChannelsResult)
StochasticIndicator - %K and %D lines (StochasticResult)

// ╚════════════════════════════════════════════════════════════════════════════════════════╝
```

## Usage Examples

### Basic Usage

```zig
const ohlcv = @import("ohlcv");

// Fetch preset data
var series = try ohlcv.fetchPreset(.btc_usd, allocator);
defer series.deinit();

// Filter by date
var filtered = try series.sliceByTime(start_ts, end_ts);
defer filtered.deinit();

// Calculate SMA
const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
var result = try sma.calculate(filtered, allocator);
defer result.deinit();
```

### Custom Data Source

```zig
// From file
var file_source = try ohlcv.FileDataSource.init(allocator, "data.csv");
defer file_source.dataSource().deinit();

// From memory
var mem_source = try ohlcv.MemoryDataSource.init(allocator, csv_data, false);
defer mem_source.dataSource().deinit();

// Parse data
const data = try source.dataSource().fetch(allocator);
defer allocator.free(data);

const parser = ohlcv.CsvParser{ .allocator = allocator };
var series = try parser.parse(data);
defer series.deinit();
```

### Streaming Large Files

```zig
// Process huge CSV files without loading into memory
var parser = ohlcv.StreamingCsvParser.init(allocator);
defer parser.deinit();

const file = try std.fs.cwd().openFile("huge_dataset.csv", .{});
defer file.close();

while (try parser.parseChunk(file.reader())) |chunk| {
    defer chunk.deinit();
    // Process each chunk
    for (chunk.rows) |row| {
        // Your logic here
    }
}
```

### Memory Pool for Performance

```zig
// Create a memory pool for efficient allocations
var pool = try ohlcv.MemoryPool.init(allocator, 1024 * 1024); // 1MB
defer pool.deinit();

// Use arena for batch calculations
var arena = ohlcv.IndicatorArena.init(&pool);

// Calculate multiple indicators without individual allocations
const sma_result = try sma.calculateWithArena(series, &arena);
const ema_result = try ema.calculateWithArena(series, &arena);
const rsi_result = try rsi.calculateWithArena(series, &arena);
// All results automatically freed when arena is reset or destroyed
```

### Advanced Operations

```zig
// Chain operations
const high_volume_days = try series
    .sliceByTime(start, end)
    .filter(struct {
        fn predicate(row: ohlcv.OhlcvRow) bool {
            return row.u64_volume > 1_000_000;
        }
    }.predicate);

// Multiple indicators
const indicators = .{
    ohlcv.SmaIndicator{ .u32_period = 20 },
    ohlcv.EmaIndicator{ .u32_period = 12 },
    ohlcv.RsiIndicator{ .u32_period = 14 },
    ohlcv.AtrIndicator{ .u32_period = 14 },
    ohlcv.WmaIndicator{ .u32_period = 10 },
};

inline for (indicators) |indicator| {
    var result = try indicator.calculate(series, allocator);
    defer result.deinit();
    // Process results...
}
```

## Performance Considerations

1. **Pre-allocation** - Parser estimates row count for efficient allocation
2. **Zero-copy slicing** - Time series slices don't copy data when possible
3. **Efficient algorithms** - Rolling calculations for indicators
4. **SIMD-ready** - Data structures aligned for future SIMD optimizations
5. **Streaming parser** - Process gigabyte-sized files with minimal memory
6. **Memory pooling** - Reduce allocation overhead in hot paths
7. **Fast parsing** - Optimized line counting and parsing primitives
8. **Benchmarking** - Comprehensive performance testing suite available

## Extending the Library

### Adding a New Indicator

```zig
// ╔══════════════════════════════════════ Custom Indicator ══════════════════════════════════════╗
pub const CustomIndicator = struct {
    const Self = @This();

    // [box] Attributes
    u32_period: u32 = 14,
    f64_multiplier: f64 = 2.0,
    // [box]
    
    // [box] Error
    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };
    // [box]
    
    // [box] Calculate Custom Indicator
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        // Implementation with proper box organization...
    }
    // [box]
};
// ╚════════════════════════════════════════════════════════════════════════════════════════════╝
```

### Adding a New Data Source

```zig
// ╔══════════════════════════════════════ API Data Source ══════════════════════════════════════╗
pub const ApiDataSource = struct {
    // Fields...
    
    pub fn dataSource(self: *Self) DataSource {
        return .{
            .ptr = self,
            .vtable = &.{
                .fetchFn = fetchImpl,
                .deinitFn = deinitImpl,
            },
        };
    }
    
    fn fetchImpl(ptr: *anyopaque, allocator: Allocator) anyerror![]u8 {
        // Implementation...
    }
};
// ╚════════════════════════════════════════════════════════════════════════════════════════════╝
```

## Migration from v2

- Direct use of `OhlcvRow` and `OhlcBar` types
- `fetchPreset()` for preset data sources
- Streaming parser for large datasets
- Memory pooling for performance optimization
- All 37 indicators fully implemented

The architecture provides maximum flexibility and performance for financial data processing.