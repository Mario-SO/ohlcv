# OHLCV Library Architecture v2.0

## Overview

The OHLCV library has been refactored for better performance, cleaner API, and improved extensibility. Key improvements include:

- **Decoupled data sources** - Easy to add custom data providers
- **Efficient time series container** - Zero-copy operations where possible
- **Clean indicator framework** - Consistent API across all indicators
- **Hungarian notation** - Clear type information in variable names
- **Performance optimizations** - Pre-allocation, SIMD-ready structures

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
// ╚════════════════════════════════════════════════════════════════════════════════════════╝
```

### 3. Time Series Container

```zig
// ╔══════════════════════════════════════ Time Series ══════════════════════════════════════╗
TimeSeries - Efficient container with:
  - Zero-copy slicing by time
  - Filter operations
  - Iterator support
  - Map transformations
// ╚════════════════════════════════════════════════════════════════════════════════════════╝
```

### 4. Indicators

```zig
// ╔══════════════════════════════════════ Indicators ══════════════════════════════════════╗
SmaIndicator - Simple Moving Average
EmaIndicator - Exponential Moving Average
RsiIndicator - Relative Strength Index
// All return IndicatorResult with timestamps and values
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

## Extending the Library

### Adding a New Indicator

```zig
// ╔══════════════════════════════════════ Custom Indicator ══════════════════════════════════════╗
pub const MacdIndicator = struct {
    u32_fast_period: u32 = 12,
    u32_slow_period: u32 = 26,
    u32_signal_period: u32 = 9,
    
    pub const Error = error{
        InsufficientData,
        InvalidParameters,
        OutOfMemory,
    };
    
    pub fn calculate(self: Self, series: TimeSeries, allocator: Allocator) Error!IndicatorResult {
        // Implementation...
    }
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

## Migration from v1

- `Row` → `OhlcvRow` (legacy alias available)
- `Bar` → `OhlcBar` (legacy alias available)
- `fetch()` → `fetchPreset()` or custom DataSource
- `indicators.calculateSMAForRange()` → Create TimeSeries, filter, then calculate
- Direct indicator structs instead of nested namespace

The new architecture provides more flexibility while maintaining ease of use for common operations.