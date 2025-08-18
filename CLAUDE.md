# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A high-performance Zig library for fetching and parsing OHLCV (Open-High-Low-Close-Volume) financial data from remote CSV files. The library provides technical indicators, time series management, and efficient data processing with explicit memory management.

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
   - **37 indicators** including trend, momentum, volatility, volume, and advanced systems
   - Each indicator implements a `calculate()` method returning `IndicatorResult`
   - Results can have multiple lines (e.g., MACD has signal and histogram)

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
- **Unit tests** in `test/unit/` for individual components
- **Integration tests** in `test/integration/` for end-to-end workflows
- **Test helpers** in `test/test_helpers.zig` for common test utilities
- All tests are imported through `test/test_all.zig`

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
   - Use `.ReleaseFast` optimization for benchmarks
   - Library supports both module import and static linking
   - Comprehensive benchmarking suite:
     - `benchmark-performance` for detailed performance metrics
     - `benchmark-streaming` for comparing parsing strategies
     - `profile-memory` for memory usage analysis
   - Memory pooling reduces allocation overhead
   - Fast parser uses optimized primitives for line counting

## GitHub Workflows

The project has comprehensive CI/CD:
- `test.yml` - Runs tests on push/PR across multiple platforms
- `performance.yml` - Tracks performance benchmarks
- `daily_update.yml` - Updates market data daily
- `coverage.yml` - Tracks test coverage

## Data Update Process

The `scripts/update_assets.py` script fetches latest market data and commits to the repository. This runs daily via GitHub Actions to keep preset data current.