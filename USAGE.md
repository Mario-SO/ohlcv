# Using OHLCV Library in Your Project

This guide explains how to add and use the OHLCV library as a dependency in your Zig project.

## Quick Start

### 1. Fetch the Library

From your project directory, run:

```bash
# Using latest main branch
zig fetch --save https://github.com/Mario-SO/ohlcv/archive/refs/heads/main.tar.gz

# Or using a specific release (when available)
zig fetch --save https://github.com/Mario-SO/ohlcv/archive/refs/tags/v1.0.0.tar.gz

# Or using git protocol
zig fetch --save git+https://github.com/Mario-SO/ohlcv#main
```

This will:
- Download the library
- Save it to your local zig cache
- Update your `build.zig.zon` with the dependency

### 2. Configure build.zig

Add the dependency to your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add the OHLCV dependency
    const ohlcv_dep = b.dependency("ohlcv", .{
        .target = target,
        .optimize = optimize,
    });

    // Create your executable
    const exe = b.addExecutable(.{
        .name = "my-trading-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import the OHLCV module
    exe.root_module.addImport("ohlcv", ohlcv_dep.module("ohlcv"));

    // Install the executable
    b.installArtifact(exe);
}
```

### 3. Use in Your Code

```zig
const std = @import("std");
const ohlcv = @import("ohlcv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Fetch preset data
    var series = try ohlcv.fetchPreset(.btc_usd, allocator);
    defer series.deinit();

    std.debug.print("Loaded {d} rows\n", .{series.len()});

    // Calculate indicators
    const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
    var result = try sma.calculate(series, allocator);
    defer result.deinit();

    // Use the results
    for (result.arr_values, result.arr_timestamps) |value, timestamp| {
        std.debug.print("{d}: {d:.2}\n", .{ timestamp, value });
    }
}
```

## Complete Example Project

### build.zig.zon
```zig
.{
    .name = "my-trading-app",
    .version = "0.0.1",
    .dependencies = .{
        .ohlcv = .{
            .url = "https://github.com/Mario-SO/ohlcv/archive/refs/heads/main.tar.gz",
            .hash = "1220...", // Will be added by zig fetch
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

### src/main.zig
```zig
const std = @import("std");
const ohlcv = @import("ohlcv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Example 1: Load and analyze Bitcoin data
    try analyzeBitcoin(allocator);

    // Example 2: Parse custom CSV data
    try parseCustomData(allocator);

    // Example 3: Calculate multiple indicators
    try calculateIndicators(allocator);
}

fn analyzeBitcoin(allocator: std.mem.Allocator) !void {
    // Fetch Bitcoin data
    var series = try ohlcv.fetchPreset(.btc_usd, allocator);
    defer series.deinit();

    // Filter by date range (2024 data)
    const start = 1704067200; // 2024-01-01
    const end = 1735689599;   // 2024-12-31
    var filtered = try series.sliceByTime(start, end);
    defer filtered.deinit();

    // Calculate RSI
    const rsi = ohlcv.RsiIndicator{ .u32_period = 14 };
    var rsi_result = try rsi.calculate(filtered, allocator);
    defer rsi_result.deinit();

    std.debug.print("Bitcoin RSI: {d:.2}\n", .{
        rsi_result.arr_values[rsi_result.len() - 1]
    });
}

fn parseCustomData(allocator: std.mem.Allocator) !void {
    const csv_data =
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,105.0,115.0,100.0,112.0,1200000
    ;

    // Create memory data source
    var source = try ohlcv.MemoryDataSource.init(allocator, csv_data, false);
    defer source.dataSource().deinit();

    // Fetch and parse
    const data = try source.dataSource().fetch(allocator);
    defer allocator.free(data);

    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var series = try parser.parse(data);
    defer series.deinit();

    std.debug.print("Parsed {d} rows\n", .{series.len()});
}

fn calculateIndicators(allocator: std.mem.Allocator) !void {
    // Load S&P 500 data
    var series = try ohlcv.fetchPreset(.sp500, allocator);
    defer series.deinit();

    // Calculate multiple indicators
    const indicators = .{
        ohlcv.SmaIndicator{ .u32_period = 50 },
        ohlcv.EmaIndicator{ .u32_period = 20 },
        ohlcv.RsiIndicator{ .u32_period = 14 },
    };

    inline for (indicators) |indicator| {
        var result = try indicator.calculate(series, allocator);
        defer result.deinit();
        
        const last_value = result.arr_values[result.len() - 1];
        std.debug.print("{s}: {d:.2}\n", .{
            @typeName(@TypeOf(indicator)),
            last_value,
        });
    }
}
```

## Advanced Usage

### Using Streaming Parser for Large Files

```zig
const std = @import("std");
const ohlcv = @import("ohlcv");

fn processLargeDataset(allocator: std.mem.Allocator) !void {
    var parser = ohlcv.StreamingCsvParser.init(allocator);
    defer parser.deinit();
    
    const file = try std.fs.cwd().openFile("huge_dataset.csv", .{});
    defer file.close();
    
    while (try parser.parseChunk(file.reader())) |chunk| {
        defer chunk.deinit();
        
        for (chunk.rows) |row| {
            // Process each row without loading entire file
            if (row.f64_close > 1000.0) {
                std.debug.print("High value: {d}\n", .{row.f64_close});
            }
        }
    }
}
```

### Using Memory Pools for Performance

```zig
fn highPerformanceCalculations(allocator: std.mem.Allocator) !void {
    // Create memory pool for efficient allocations
    var pool = try ohlcv.MemoryPool.init(allocator, 1024 * 1024); // 1MB
    defer pool.deinit();

    var arena = ohlcv.IndicatorArena.init(&pool);
    
    var series = try ohlcv.fetchPreset(.btc_usd, allocator);
    defer series.deinit();

    // Calculate multiple indicators without individual allocations
    const sma_result = try sma.calculateWithArena(series, &arena);
    const ema_result = try ema.calculateWithArena(series, &arena);
    const rsi_result = try rsi.calculateWithArena(series, &arena);
    
    // All results freed when arena is destroyed
}
```

### Custom Data Sources

```zig
// From HTTP URL
var http_source = try ohlcv.HttpDataSource.init(
    allocator,
    "https://example.com/data.csv"
);
defer http_source.dataSource().deinit();

// From local file
var file_source = try ohlcv.FileDataSource.init(
    allocator,
    "/path/to/data.csv"
);
defer file_source.dataSource().deinit();

// Use the data source
const data = try file_source.dataSource().fetch(allocator);
defer allocator.free(data);
```

## Available Indicators

The library provides 37 technical indicators:

### Trend Indicators
- `SmaIndicator` - Simple Moving Average
- `EmaIndicator` - Exponential Moving Average
- `WmaIndicator` - Weighted Moving Average
- `AdxIndicator` - Average Directional Index
- `DmiIndicator` - Directional Movement Index
- `ParabolicSarIndicator` - Parabolic SAR

### Momentum Indicators
- `RsiIndicator` - Relative Strength Index
- `MacdIndicator` - MACD with signal and histogram
- `StochasticIndicator` - Stochastic Oscillator
- `StochasticRsiIndicator` - Stochastic RSI
- `MomentumIndicator` - Momentum
- `RocIndicator` - Rate of Change
- `WilliamsRIndicator` - Williams %R
- `TrixIndicator` - TRIX
- `UltimateOscillatorIndicator` - Ultimate Oscillator

### Volatility Indicators
- `AtrIndicator` - Average True Range
- `BollingerBandsIndicator` - Bollinger Bands
- `KeltnerChannelsIndicator` - Keltner Channels
- `DonchianChannelsIndicator` - Donchian Channels
- `PriceChannelsIndicator` - Price Channels

### Volume Indicators
- `ObvIndicator` - On-Balance Volume
- `MfiIndicator` - Money Flow Index
- `CmfIndicator` - Chaikin Money Flow
- `ForceIndexIndicator` - Force Index
- `AccumulationDistributionIndicator` - A/D Line
- `VwapIndicator` - VWAP
- `CciIndicator` - Commodity Channel Index

### Advanced Systems
- `IchimokuCloudIndicator` - Ichimoku Cloud
- `HeikinAshiIndicator` - Heikin Ashi
- `PivotPointsIndicator` - Pivot Points
- `ElderRayIndicator` - Elder Ray
- `AroonIndicator` - Aroon
- `ZigZagIndicator` - Zig Zag

## Error Handling

```zig
// Handle specific errors
series = ohlcv.fetchPreset(.btc_usd, allocator) catch |err| {
    switch (err) {
        error.HttpError => std.debug.print("Network error\n", .{}),
        error.ParseError => std.debug.print("Invalid CSV format\n", .{}),
        error.OutOfMemory => std.debug.print("Not enough memory\n", .{}),
        else => return err,
    }
    return;
};
```

## Performance Tips

1. **Use streaming parser** for files >100MB
2. **Use memory pools** when calculating many indicators
3. **Pre-filter data** with `sliceByTime()` before calculations
4. **Reuse TimeSeries** objects when possible
5. **Use `.ReleaseFast` optimization** for production

## Troubleshooting

### "Hash mismatch" error
Delete the hash field and run `zig fetch` again to get the correct hash.

### "Module not found" error
Ensure the import name matches exactly: `@import("ohlcv")`

### Performance issues
- Use streaming parser for large files
- Enable optimizations: `-Doptimize=ReleaseFast`
- Use memory pools for repeated calculations

## Support

- GitHub Issues: https://github.com/Mario-SO/ohlcv/issues
- Documentation: See README.md and lib/README.md
- Examples: See demo.zig for comprehensive examples