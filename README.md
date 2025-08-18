# 📊 OHLCV Zig Library

[![CI](https://github.com/Mario-SO/ohlcv/actions/workflows/ci.yml/badge.svg)](https://github.com/Mario-SO/ohlcv/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Zig Version](https://img.shields.io/badge/Zig-0.14.0+-orange.svg)](https://ziglang.org/)

A modern Zig library for fetching and parsing Open-High-Low-Close-Volume (OHLCV) financial data from remote CSV files—no API keys or registration required.

---

## ✨ Features

- **Multiple Data Sources**: HTTP, local files, in-memory data

- **Preset Datasets**: BTC, S&P 500, ETH, Gold (from GitHub or local)

- **High-Performance Parsing**: 
  - Standard CSV parser with robust error handling
  - **NEW**: Streaming CSV parser for processing large datasets without full memory load
  - **NEW**: Optimized fast parser with SIMD-aware line counting
  - Handles headers, skips invalid/zero rows automatically

- **Memory Management**:
  - **NEW**: Memory pooling system for efficient allocation reuse
  - **NEW**: IndicatorArena for batch indicator calculations
  - All allocations are explicit and easy to free

- **Time Series Management**: Efficient slicing, filtering, and operations

- **37 Technical Indicators**: Complete suite including trend (SMA, EMA, ADX), momentum (RSI, MACD, Stochastic), volatility (Bollinger Bands, ATR, Keltner Channels), volume (OBV, MFI, CMF), and advanced systems (Ichimoku Cloud, Heikin Ashi)

- **Performance Testing**:
  - **NEW**: Comprehensive performance benchmarks
  - **NEW**: Streaming vs non-streaming comparison tools
  - Memory profiling capabilities

- **Extensible**: add new data sources, indicators, or parsers easily

---

## 🏗️ Building & Running

1. **Build the library and demo:**
   ```sh
   zig build
   ```
2. **Run the demo application:**
   ```sh
   zig build run
   ```
   The demo fetches S&P 500 data and prints a sample of parsed rows.

3. **Run tests:**
   ```sh
   zig build test
   ```

4. **Run benchmarks:**
   ```sh
   zig build benchmark              # Basic benchmark
   zig build benchmark-performance   # Comprehensive performance tests
   zig build benchmark-streaming     # Compare streaming vs non-streaming
   zig build profile-memory         # Memory usage profiler
   ```


---

## 📦 Using as a Library

### Add to Your Project

```bash
# Fetch from GitHub
zig fetch --save https://github.com/Mario-SO/ohlcv/archive/refs/heads/main.tar.gz
```

### Configure build.zig

```zig
const ohlcv_dep = b.dependency("ohlcv", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("ohlcv", ohlcv_dep.module("ohlcv"));
```

### Import and Use

```zig
const ohlcv = @import("ohlcv");

// Your code here
var series = try ohlcv.fetchPreset(.btc_usd, allocator);
defer series.deinit();
```

See [USAGE.md](USAGE.md) for detailed integration guide.

## 🚀 Usage Example

```zig
const std = @import("std");
const ohlcv = @import("lib/ohlcv.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Fetch preset data
    var series = try ohlcv.fetchPreset(.sp500, allocator);
    defer series.deinit();

    std.debug.print("Fetched {d} rows of data.\n", .{series.len()});

    // Slice by time range
    const from_ts = 1672531200; // 2023-01-01
    const to_ts = 1704067199; // 2023-12-31
    var filtered = try series.sliceByTime(from_ts, to_ts);
    defer filtered.deinit();

    // Calculate SMA
    const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
    var result = try sma.calculate(filtered, allocator);
    defer result.deinit();

    // Print sample
    const count = @min(5, result.len());
    for (0..count) |i| {
        std.debug.print("TS: {d}, SMA: {d:.2}\n", .{result.arr_timestamps[i], result.arr_values[i]});
    }
}
```

### Streaming Large Datasets

```zig
const std = @import("std");
const ohlcv = @import("lib/ohlcv.zig");

pub fn processLargeDataset(allocator: std.mem.Allocator) !void {
    // Use streaming parser for large files
    var parser = ohlcv.StreamingCsvParser.init(allocator);
    defer parser.deinit();
    
    // Process data in chunks without loading entire file
    const file = try std.fs.cwd().openFile("huge_dataset.csv", .{});
    defer file.close();
    
    while (try parser.parseChunk(file.reader())) |chunk| {
        defer chunk.deinit();
        // Process each chunk independently
        for (chunk.rows) |row| {
            // Your processing logic here
        }
    }
}
```

### Memory Pool Usage

```zig
// Use memory pool for efficient indicator calculations
var pool = try ohlcv.MemoryPool.init(allocator, 1024 * 1024); // 1MB pool
defer pool.deinit();

var arena = ohlcv.IndicatorArena.init(&pool);
// All allocations within arena are automatically managed
const result = try sma.calculateWithArena(series, &arena);
// No need to manually free result - arena handles it
```

---

## 🧑‍💻 API Overview

### Types

- `OhlcvRow` — Full OHLCV record:
  ```zig
  pub const OhlcvRow = struct {
      u64_timestamp: u64,
      f64_open: f64,
      f64_high: f64,
      f64_low: f64,
      f64_close: f64,
      u64_volume: u64,
  };
  ```

- `OhlcBar` — OHLC without volume:
  ```zig
  pub const OhlcBar = struct {
      u64_timestamp: u64,
      f64_open: f64,
      f64_high: f64,
      f64_low: f64,
      f64_close: f64,
  };
  ```

- `PresetSource` — Available presets:
  ```zig
  pub const PresetSource = enum { btc_usd, sp500, eth_usd, gold_usd };
  ```

- `TimeSeries` — Data container with operations

- `IndicatorResult` — Results from indicators

### Key Components

- **Data Sources**: `DataSource`, `HttpDataSource`, `FileDataSource`, `MemoryDataSource`

- **Parsers**: 
  - `CsvParser` - Standard CSV parser with robust error handling
  - `StreamingCsvParser` - Process large files in chunks
  - Fast parser primitives for optimized parsing

- **Memory Management**:
  - `MemoryPool` - Reusable memory allocation pool
  - `IndicatorArena` - Arena allocator for batch calculations

- **37 Indicators**: Including trend analysis (SMA, EMA, WMA, ADX, DMI, Parabolic SAR), momentum oscillators (RSI, MACD, Stochastic, Stochastic RSI, Ultimate Oscillator, TRIX), volatility bands (Bollinger Bands, Keltner Channels, Donchian Channels, Price Channels), volume analysis (OBV, MFI, CMF, Force Index, A/D Line), and advanced systems (Ichimoku Cloud, Heikin Ashi, Pivot Points, Elder Ray, Aroon, Zig Zag)

- **Convenience**: `fetchPreset(source: PresetSource, allocator) !TimeSeries`

For detailed usage, see [ARCHITECTURE.md](ARCHITECTURE.md)

### Errors

- `ParseError` — Possible parsing errors:
  - `InvalidFormat`, `InvalidTimestamp`, `InvalidOpen`, `InvalidHigh`, `InvalidLow`, `InvalidClose`, `InvalidVolume`, `InvalidDateFormat`, `DateBeforeEpoch`, `OutOfMemory`, `EndOfStream`
- `FetchError` — `HttpError` or any `ParseError`

---

## 📁 Project Structure

```
ohlcv/
  - ARCHITECTURE.md
  - CLAUDE.md              # Claude Code guidance
  - PROFILING.md           # Performance profiling guide
  - build.zig
  - build.zig.zon
  - benchmark/
    - performance_benchmark.zig
    - simple_benchmark.zig
    - simple_memory_profiler.zig
    - streaming_benchmark.zig
  - data/
    - btc.csv
    - eth.csv
    - gold.csv
    - sp500.csv
  - demo.zig
  - lib/
    - data_source/
      - data_source.zig
      - file_data_source.zig
      - http_data_source.zig
      - memory_data_source.zig
    - indicators/         # 37 technical indicators
      - indicator_result.zig
      - [Single-line indicators: SMA, EMA, WMA, RSI, ATR, ROC, Momentum, etc.]
      - [Multi-line indicators: MACD, Bollinger Bands, Ichimoku Cloud, etc.]
      - README.md         # Complete indicator documentation
    - ohlcv.zig
    - parser/
      - csv_parser.zig
      - fast_parser.zig         # Optimized parsing primitives
      - streaming_csv_parser.zig # Chunked processing
    - utils/
      - date.zig
      - memory_pool.zig         # Memory pooling system
      - time_series.zig
    - types/
      - ohlc_bar.zig
      - ohlcv_row.zig
  - README.md
  - scripts/
    - boxify.ts
    - update_assets.py
  - test/
    - fixtures/
      - sample_data.csv
    - integration/
      - test_full_workflow.zig
    - README.md
    - test_all.zig
    - test_helpers.zig
    - unit/
      - test_csv_parser.zig
      - test_data_sources.zig
      - test_indicators.zig
      - test_time_series.zig
  - zig-out/
```

---

## ⚠️ Row Skipping & Data Cleaning

- The parser **skips**:
  - The header row
  - Rows with invalid format or parser errors
  - Rows with pre-1970 dates
  - Rows where any of the OHLCV values are zero
- This means the number of parsed rows may be less than the number of lines in the CSV file.

---

## 🧩 Extending & Contributing

- Add new formats: add new parser functions in `parser.zig`
- PRs and issues welcome!

---

## 📚 See Also

- [demo.zig](demo.zig) — Full example usage
- [ARCHITECTURE.md](ARCHITECTURE.md) — Detailed architecture, examples, and extension guide
- [lib/ohlcv.zig](lib/ohlcv.zig) — Public API

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Made with ❤️ using Zig** 
