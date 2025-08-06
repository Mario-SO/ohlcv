# 📊 OHLCV Zig Library

A modern Zig library for fetching and parsing Open-High-Low-Close-Volume (OHLCV) financial data from remote CSV files—no API keys or registration required.

---

## ✨ Features

- **Multiple Data Sources**: HTTP, local files, in-memory data

- **Preset Datasets**: BTC, S&P 500, ETH, Gold (from GitHub or local)

- **Fast, robust CSV parsing** (handles headers, skips invalid/zero rows)

- **Time Series Management**: Efficient slicing, filtering, and operations

- **Technical Indicators**: SMA, EMA, RSI, MACD, Bollinger Bands, ATR, Stochastic, Williams %R, WMA, ROC, Momentum with extensible framework

- **Memory safe**: all allocations are explicit, easy to free

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


---

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

- Data Sources: `DataSource`, `HttpDataSource`, `FileDataSource`, `MemoryDataSource`

- Parser: `CsvParser`

- Indicators: `SmaIndicator`, `EmaIndicator`, `RsiIndicator`, `MacdIndicator`, `BollingerBandsIndicator`, `AtrIndicator`, `StochasticIndicator`, `WilliamsRIndicator`, `WmaIndicator`, `RocIndicator`, `MomentumIndicator`

- Convenience: `fetchPreset(source: PresetSource, allocator) !TimeSeries`

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
  - build.zig
  - build.zig.zon
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
    - indicators/
      - atr_indicator.zig
      - bollinger_bands_indicator.zig
      - ema_indicator.zig
      - indicator_result.zig
      - macd_indicator.zig
      - momentum_indicator.zig
      - roc_indicator.zig
      - rsi_indicator.zig
      - sma_indicator.zig
      - stochastic_indicator.zig
      - williams_r_indicator.zig
      - wma_indicator.zig
    - ohlcv.zig
    - parser/
      - csv_parser.zig
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

MIT License 
