# 📊 OHLCV Zig Library

A modern Zig library for fetching and parsing Open-High-Low-Close-Volume (OHLCV) financial data from remote CSV files—no API keys or registration required.

---

## ✨ Features

- **Fetch remote OHLCV data** for BTC, S&P 500, ETH, and Gold (from GitHub)
- **Fast, robust CSV parsing** (handles headers, skips invalid/zero rows)
- **Simple, ergonomic API** (single import, clear types)
- **Memory safe**: all allocations are explicit, easy to free
- **Extensible**: add new data sources or formats easily

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
3. **Run unit tests:**
   ```sh
   zig build test
   ```

---

## 🚀 Usage Example

```zig
const std = @import("std");
const ohlcv = @import("lib/ohlcv.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    // Fetch S&P 500 data (network + parser)
    const rows = try ohlcv.fetch(.sp500, alloc);
    defer alloc.free(rows);

    std.debug.print("Fetched {d} rows of data.\n", .{rows.len});

    // Print the first 5 rows as a sample
    const count = if (rows.len < 5) rows.len else 5;
    for (rows[0..count], 0..) |row, i| {
        std.debug.print("Row {d}: ts={d}, o={d:.2}, h={d:.2}, l={d:.2}, c={d:.2}, v={d}\n",
            .{i, row.ts, row.o, row.h, row.l, row.c, row.v});
    }
}
```

---

## 🧑‍💻 API Overview

### Types

- `Row` — One OHLCV record:
  ```zig
  const Row = struct {
      ts: u64,   // Unix timestamp (seconds)
      o: f64,    // Open
      h: f64,    // High
      l: f64,    // Low
      c: f64,    // Close
      v: u64,    // Volume
  };
  ```
- `Bar` — OHLC (no volume):
  ```zig
  const Bar = struct {
      ts: u64, o: f64, h: f64, l: f64, c: f64
  };
  ```
- `DataSet` — Enum of available remote datasets:
  ```zig
  const DataSet = enum { btc_usd, sp500, eth_usd, gold_usd };
  ```

### Functions

- `fetch(ds: DataSet, alloc: Allocator) FetchError![]Row` — Fetch and parser remote CSV
- `parseCsv(alloc, reader) ![]Row` — Parse CSV from any reader (default parser)
- `parseCsvFast(alloc, reader) ![]Row` — Fast state-machine parser
- `parseFileCsv(alloc, path) ![]Row` — Parse CSV from file
- `parseStringCsv(alloc, data) ![]Row` — Parse CSV from in-memory string

### Errors

- `ParseError` — Possible parsing errors:
  - `InvalidFormat`, `InvalidTimestamp`, `InvalidOpen`, `InvalidHigh`, `InvalidLow`, `InvalidClose`, `InvalidVolume`, `InvalidDateFormat`, `DateBeforeEpoch`, `OutOfMemory`, `EndOfStream`
- `FetchError` — `HttpError` or any `ParseError`

---

## 📁 Project Structure

```
.
├── build.zig         # Build script
├── build.zig.zon     # Package manifest
├── demo.zig          # Example usage executable
├── lib/              # Library source code
│   ├── ohlcv.zig     # Barrel: public API (import this)
│   ├── types.zig     # Row, Bar
│   ├── errors.zig    # Error types
│   ├── fetch.zig     # DataSet, fetch()
│   ├── parser.zig     # Parsing API
│   ├── util/         # Internal helpers (date)
│   └── parser/        # Internal parsing logic
└── README.md         # This file
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
- [lib/ohlcv.zig](lib/ohlcv.zig) — Public API

---

MIT License 