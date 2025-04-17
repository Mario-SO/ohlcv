# 📊 OHLCV Zig Library

A Zig library for fetching and parsing Open High Low Close Volume (OHLCV) data from remote CSV files. 📈

## ✨ Features

*   **Fetch Data:** Downloads OHLCV CSV data for various assets (BTC, S&P 500, ETH, Gold) directly from GitHub. ☁️
*   **Fast Parsing:** Efficiently parses CSV data into structured Zig types (`Row`). ⚡
*   **Modular Design:** Clear separation of concerns:
    *   `core/`: Defines core data types (`Row`, `Bar`).
    *   `parse/`: Handles CSV parsing logic.
    *   `provider/`: Manages data fetching via HTTP.
*   **Simple API:** Easy-to-use functions (`fetch`, `parseAll`).

## 🏗️ Building

This project uses the Zig build system.

1.  **Build the library and demo:**
    ```bash
    zig build
    ```
2.  **Run the demo application:**
    ```bash
    zig build run
    ```
    The demo fetches S&P 500 data and prints memory usage statistics.
3.  **Run unit tests:**
    ```bash
    zig build test
    ```

## 🚀 Usage Example

Here's a basic example:

```zig
const std = @import("std");
const print = std.debug.print;

const ohlcv = @import("ohlcv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    // Fetch S&P 500 data
    const rows = try ohlcv.fetch(.sp500, alloc);
    defer alloc.free(rows); // Remember to free the allocated memory

    std.debug.print("Fetched {d} rows of data.\n", .{rows.len});

    // Process the 'rows' slice...
    for (rows) |row| {
        // Access row data: row.ts, row.o, row.h, row.l, row.c, row.v
    }
}

```

See `lib/lib.zig` for the main library exports and `demo.zig` for a runnable example.

## 📁 Project Structure

```
.
├── build.zig         # Build script
├── build.zig.zon     # Package manifest
├── demo.zig          # Example usage executable
├── lib/              # Library source code
│   ├── core/         # Core data types (Row, Bar)
│   ├── parse/        # CSV parsing logic
│   └── provider/     # Data fetching (HTTP)
│   └── lib.zig       # Main library file
└── README.md         # This file
``` 