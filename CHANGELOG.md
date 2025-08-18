# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-18

### 🎉 Initial Release

#### Features
- **37 Technical Indicators** - Complete suite of trading indicators:
  - Trend: SMA, EMA, WMA, ADX, DMI, Parabolic SAR
  - Momentum: RSI, MACD, Stochastic, Williams %R, ROC, TRIX, and more
  - Volatility: ATR, Bollinger Bands, Keltner Channels, Donchian Channels
  - Volume: OBV, MFI, CMF, Force Index, Accumulation/Distribution
  - Advanced: Ichimoku Cloud, Heikin Ashi, Pivot Points, Elder Ray, Aroon, Zig Zag

- **High-Performance Parsing**:
  - Standard CSV parser with 15,000+ rows/ms throughput
  - Streaming parser for processing gigabyte-sized files with constant 4KB memory
  - Optimized fast parser primitives with SIMD-aware line counting
  - Robust error handling (skips invalid rows automatically)

- **Memory Management**:
  - Memory pooling system for efficient allocation reuse
  - IndicatorArena for batch indicator calculations
  - Zero memory leaks verified across all components

- **Data Sources**:
  - HTTP data source for remote CSV files
  - File data source for local files
  - Memory data source for in-memory data
  - Preset sources: Bitcoin, S&P 500, Ethereum, Gold

- **Time Series Operations**:
  - Efficient slicing by time range
  - Filtering with custom predicates
  - Sorting and transformation operations
  - Zero-copy operations where possible

#### Performance
- Parser throughput: 15,000+ rows/millisecond
- SMA-20 calculation: <0.03ms for 1K data points
- Memory usage: ~47KB per 1K OHLCV rows
- Streaming mode: Constant 4KB regardless of file size

#### Infrastructure
- Comprehensive test suite with 100% indicator coverage
- GitHub Actions CI/CD pipeline (3 streamlined workflows)
- Automated daily market data updates
- Performance benchmarking suite
- Memory profiling tools

#### Documentation
- Complete API documentation
- Usage guide with examples
- Architecture documentation
- Performance monitoring guide

### Known Limitations
- Requires Zig 0.14.0 or higher
- CSV dates before 1970 are skipped
- Rows with zero values are filtered out

[1.0.0]: https://github.com/Mario-SO/ohlcv/releases/tag/v1.0.0