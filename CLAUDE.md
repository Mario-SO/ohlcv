# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A modern, high-performance Zig library for fetching and parsing OHLCV (Open-High-Low-Close-Volume) financial data from remote CSV files. The library provides:

- **33 technical indicators** covering trend, momentum, volatility, volume, and advanced trading systems
- **Multiple data sources** (HTTP, local files, in-memory)
- **High-performance parsing** with streaming support for large datasets
- **Advanced memory management** with pooling and arena allocation
- **Comprehensive benchmarking** and performance monitoring
- **Clean, explicit API** with Zig's memory safety guarantees

## Build and Development Commands

### Core Commands
```bash
# Build the library and demo
zig build

# Run the demo application
zig build run

# Run all tests
zig build test

# Run benchmarks
zig build benchmark                # Basic benchmark
zig build benchmark-performance     # Comprehensive performance tests
zig build benchmark-streaming       # Streaming vs non-streaming comparison

# Run memory profiler
zig build profile-memory
```

### Testing Individual Components
```bash
# Run specific test file (example)
zig test test/unit/test_time_series.zig -I lib --dep ohlcv -Mohlcv=lib/ohlcv.zig
```

## Architecture Overview

### Module Organization
The library is exposed through `lib/ohlcv.zig` which re-exports all public APIs. The codebase follows a clean separation of concerns:

1. **Data Sources** (`lib/data_source/`)
   - `DataSource` interface for polymorphic data access
   - `HttpDataSource` for fetching from URLs
   - `FileDataSource` for local files  
   - `MemoryDataSource` for in-memory data

2. **Parsing** (`lib/parser/`)
   - `CsvParser` handles CSV parsing with robust error handling
   - `StreamingCsvParser` processes large files in chunks without full memory load
   - `fast_parser.zig` provides optimized parsing primitives with SIMD-aware line counting
   - Skips invalid rows, headers, pre-1970 dates, and zero values
   - Supports multiple line endings (CRLF, LF, CR)

3. **Time Series** (`lib/utils/time_series.zig`)
   - Core container for OHLCV data
   - Provides slicing, filtering, sorting, and transformation operations
   - Memory-safe with explicit allocation/deallocation

4. **Memory Management** (`lib/utils/`)
   - `MemoryPool` provides reusable memory allocation pools
   - `IndicatorArena` offers arena allocation for batch calculations
   - Reduces allocation overhead in hot paths
   - Improves cache locality for performance-critical operations

5. **Technical Indicators** (`lib/indicators/`)
   - **33 indicators** including:
     - **Trend**: SMA, EMA, WMA, ADX, DMI, Parabolic SAR
     - **Momentum**: RSI, MACD, Stochastic, Williams %R, ROC, TRIX, Ultimate Oscillator
     - **Volatility**: ATR, Bollinger Bands, Keltner Channels, Donchian Channels, Price Channels
     - **Volume**: OBV, MFI, CMF, Force Index, Accumulation/Distribution, VWAP, CCI
     - **Advanced**: Ichimoku Cloud, Heikin Ashi, Pivot Points, Elder Ray, Aroon, Zig Zag
   - Each indicator implements a `calculate()` method returning `IndicatorResult` or specialized result types
   - Multi-line indicators (MACD, Bollinger Bands, etc.) return structured results with multiple arrays

### Memory Management Pattern
All allocations are explicit using Zig's allocator pattern:
- Functions accepting allocators return owned memory
- Caller is responsible for calling `.deinit()` on returned structures
- TimeSeries and IndicatorResult have `.deinit()` methods

### Error Handling
- `ParseError` enum for parsing failures
- `FetchError` for data retrieval issues
- Functions return error unions (`!Type`) for explicit error handling

## Key Design Patterns

### Data Flow
```
DataSource -> fetch() -> raw bytes -> CsvParser/StreamingCsvParser -> OhlcvRow[] -> TimeSeries -> Indicators -> IndicatorResult
                                              |
                                              └─> MemoryPool/IndicatorArena (optional optimization)
```

### Preset Data Sources
The library provides preset configurations for common datasets:
- `.btc_usd` - Bitcoin/USD data
- `.sp500` - S&P 500 index
- `.eth_usd` - Ethereum/USD data
- `.gold_usd` - Gold/USD data

These can be fetched either from GitHub or local CSV files in the `data/` directory.

### Testing Strategy
- **Unit tests** in `test/unit/` for individual components:
  - `test_time_series.zig` - TimeSeries container functionality
  - `test_data_sources.zig` - Data source implementations
  - `test_csv_parser.zig` - CSV parsing and streaming
  - `test_indicators.zig` - All 33 technical indicators
  - `test_edge_cases.zig` - Error conditions and edge cases
- **Integration tests** in `test/integration/` for end-to-end workflows
- **Test helpers** in `test/test_helpers.zig` for common utilities
- **Performance tests** via benchmark suite with memory leak detection
- All tests imported through `test/test_all.zig` for unified execution

## Code Conventions

### Naming
- Files: snake_case (e.g., `csv_parser.zig`)
- Types: PascalCase (e.g., `OhlcvRow`, `TimeSeries`)
- Functions: camelCase (e.g., `sliceByTime`, `calculate`)
- Fields with type prefix: `u64_timestamp`, `f64_open`, `arr_values`

### Documentation
- Boxed comments for major sections using Unicode box drawing characters
- Inline documentation for public APIs
- Test files include coverage checklists in README

### Error Handling
- Always use error unions for fallible operations
- Provide specific error types (avoid `anyerror`)
- Document error conditions in comments

## Important Implementation Notes

1. **CSV Parsing Robustness**
   - Parser automatically skips invalid rows rather than failing
   - Handles various date formats and converts to Unix timestamps
   - Validates OHLC relationships (high >= low, etc.)

2. **Indicator Calculations**
   - Most indicators require a minimum period of data
   - Results align timestamps with input data
   - Multi-line indicators use the `lines` field in IndicatorResult

3. **Performance Considerations**
   - Use `.ReleaseFast` optimization for benchmarks (automatically set)
   - Library supports both module import and static linking
   - **Comprehensive benchmarking suite**:
     - `zig build benchmark` - Quick performance test
     - `zig build benchmark-performance` - All indicators across dataset sizes
     - `zig build benchmark-streaming` - Streaming vs standard parser comparison
     - `zig build profile-memory` - Memory usage analysis with leak detection
     - `./scripts/profile.sh` - Automated profiling with result archiving
   - **Performance metrics**: 15,000+ rows/ms parsing, <0.03ms SMA-20 calculation
   - **Memory efficiency**: ~47KB per 1K OHLCV rows, constant 4KB for streaming
   - Memory pooling and arena allocation reduce allocation overhead
   - SIMD-ready data structures for future optimizations

## GitHub Workflows

The project has a streamlined CI/CD pipeline:
- `ci.yml` - Runs tests on push/PR across multiple platforms (Ubuntu, macOS, Windows)
- `performance-tracking.yml` - Weekly performance benchmark tracking
- `daily_update.yml` - Updates market data daily at market close (23:00 UTC)

## Project Structure

The project follows a clean, organized structure:

```
ohlcv/
├── CLAUDE.md              # This file - Claude Code guidance
├── README.md              # Main project documentation
├── LICENSE                # MIT license
├── build.zig              # Build configuration
├── build.zig.zon          # Package dependencies
├── demo.zig               # Example application
├── docs/                  # Extended documentation
│   ├── README.md          # Documentation index
│   ├── USAGE.md           # Detailed usage guide
│   ├── PROFILING.md       # Performance profiling guide
│   └── CHANGELOG.md       # Release history
├── lib/                   # Core library code
│   ├── ohlcv.zig          # Main API exports
│   ├── data_source/       # Data source implementations
│   ├── parser/            # CSV parsing (standard + streaming)
│   ├── indicators/        # 33 technical indicators
│   ├── types/             # Core data types (OhlcvRow, OhlcBar)
│   └── utils/             # Utilities (TimeSeries, MemoryPool)
├── test/                  # Comprehensive test suite
├── benchmark/             # Performance benchmarking tools
├── data/                  # Preset market data (BTC, ETH, Gold, S&P500)
└── scripts/               # Automation scripts
```

## Data Update Process

The `scripts/update_assets.py` script uses yfinance to fetch latest market data for BTC, ETH, Gold, and S&P 500. It runs daily via GitHub Actions (Daily Data Update workflow) at market close to keep preset data current.

## Library Usage Patterns

### Quick Start Example
```zig
const std = @import("std");
const ohlcv = @import("ohlcv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Fetch preset data
    var series = try ohlcv.fetchPreset(.sp500, allocator);
    defer series.deinit();

    // Calculate indicator
    const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
    var result = try sma.calculate(series, allocator);
    defer result.deinit();
}
```

### Memory Management Best Practices
- Always call `.deinit()` on TimeSeries and IndicatorResult
- Use MemoryPool for repeated calculations to reduce allocation overhead
- Use StreamingCsvParser for files >100MB to maintain constant memory usage
- Prefer arena allocation (IndicatorArena) for batch indicator calculations

### Common Workflows
1. **Data Analysis**: fetchPreset -> sliceByTime -> calculate indicators
2. **Custom Data**: DataSource -> parse -> TimeSeries -> indicators
3. **Streaming**: StreamingCsvParser -> process chunks -> accumulate results
4. **Performance**: MemoryPool + IndicatorArena for hot paths

## Important Development Notes

### When Adding New Indicators
1. Follow the pattern in existing indicators (see `lib/indicators/sma_indicator.zig`)
2. Use boxed comments with intelligent labels
3. Implement proper error handling with specific error types
4. Add comprehensive tests in `test/unit/test_indicators.zig`
5. Update the count in all documentation files

### When Modifying Parsers
- Maintain backward compatibility with existing CSV formats
- Test with various line endings (CRLF, LF, CR)
- Ensure robust error handling (skip invalid rows, don't fail)
- Update streaming parser if changes affect chunk processing

### Performance Considerations for Changes
- Always benchmark changes with `zig build benchmark-performance`
- Profile memory usage with `zig build profile-memory`
- Consider impact on both standard and streaming parsers
- Test with various dataset sizes (100, 1K, 10K, 50K rows)

# important-instruction-reminders
Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (*.md) or README files. Only create documentation files if explicitly requested by the User.
