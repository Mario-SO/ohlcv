# OHLCV Library Profiling & Benchmarking Guide

This guide covers various ways to benchmark and profile the OHLCV library for performance analysis and optimization.

## 🚀 Quick Start

### Built-in Benchmarking
```bash
# Run performance benchmarks
zig build benchmark

# Run memory profiling
zig build profile-memory

# Run comprehensive profiling suite
./scripts/profile.sh

# Run specific profiling tasks
./scripts/profile.sh benchmark    # Just benchmarks
./scripts/profile.sh memory       # Just memory profiling
./scripts/profile.sh system       # System information
./scripts/profile.sh compare      # Compare with previous results
```

### Available Commands
- `zig build benchmark` - Simple, fast performance benchmarks
- `zig build benchmark-performance` - Comprehensive performance tests with all indicators
- `zig build benchmark-streaming` - Compare streaming vs non-streaming parsers
- `zig build profile-memory` - Memory usage analysis
- `./scripts/profile.sh` - Automated profiling with result archiving

## 📊 Benchmark Suite

### Performance Benchmarks
The comprehensive benchmark suite tests all 37 indicators across different dataset sizes (100, 1K, 10K, 50K data points):

**Trend Indicators:**
- SMA, EMA, WMA, ADX, DMI, Parabolic SAR

**Momentum Indicators:**
- RSI, MACD, Stochastic, Stochastic RSI, Ultimate Oscillator, TRIX, ROC, Momentum, Williams %R

**Volatility Indicators:**
- Bollinger Bands, ATR, Keltner Channels, Donchian Channels, Price Channels

**Volume Indicators:**
- OBV, MFI, CMF, Force Index, Accumulation/Distribution

**Advanced Systems:**
- Ichimoku Cloud, Heikin Ashi, Pivot Points, Elder Ray, Aroon, Zig Zag, CCI, VWAP

### Parser Benchmarks
The streaming benchmark compares:
- **Standard CsvParser** - Loads entire dataset into memory
- **StreamingCsvParser** - Processes data in chunks
- **Fast Parser Primitives** - Optimized line counting and parsing

**Output includes:**
- Duration in milliseconds
- Operations per second
- Nanoseconds per operation
- Memory usage patterns

### Memory Profiling
The memory profiler tracks:
- Total allocations/deallocations
- Bytes allocated/freed
- Peak memory usage
- Memory leaks detection
- Per-indicator memory patterns

## 🔧 Advanced Profiling Tools

### 1. System-Level Profiling (macOS)

#### Using Instruments
```bash
# Build with debug symbols
zig build benchmark -Doptimize=Debug

# Profile with Instruments
xcrun xctrace record --template "Time Profiler" --launch -- ./zig-out/bin/benchmark
```

#### Using Activity Monitor
Monitor real-time resource usage:
- CPU usage per core
- Memory pressure
- Energy impact

### 2. Command Line Profiling

#### time command
```bash
time zig build benchmark
```

#### Valgrind (Linux)
```bash
valgrind --tool=massif zig build benchmark
valgrind --tool=callgrind zig build benchmark
```

#### perf (Linux)
```bash
perf record zig build benchmark
perf report
```

### 3. Zig-Specific Tools

#### Built-in Profiling
```zig
// Add to your code for detailed timing
const start = std.time.nanoTimestamp();
// ... code to profile ...
const end = std.time.nanoTimestamp();
std.debug.print("Duration: {}ns\n", .{end - start});
```

#### Memory Debugging
```bash
# Run with memory debugging
zig build benchmark -Doptimize=Debug --summary all
```

## 📈 Interpreting Results

### Performance Metrics

**Good Performance Indicators:**
- Linear scaling with data size (O(n) complexity)
- Consistent ns/op across dataset sizes
- Low memory allocations per operation

**Performance Red Flags:**
- Quadratic scaling (O(n²) complexity)
- Increasing ns/op with larger datasets
- Excessive memory allocations
- Memory leaks

### Sample Results Analysis
```
Test                                     Duration (ms)        Ops     ns/op
SMA-20 (1000 points)                             5.234       1000      52.3
SMA-20 (10000 points)                           52.441        100     524.4
SMA-20 (50000 points)                          261.105         10   26110.5
```

This shows linear scaling: 10x data = ~10x time, which is optimal.

## 🎯 Optimization Strategies

### 1. Algorithm Optimization
- Use rolling calculations instead of recalculating windows
- Implement incremental updates for real-time data
- Cache expensive computations

### 2. Memory Optimization
- Pre-allocate arrays when size is known
- Use memory pools for frequent allocations (now available via `MemoryPool`)
- Use arena allocators for batch operations (`IndicatorArena`)
- Implement zero-copy operations where possible
- Leverage streaming parser for large datasets to reduce memory footprint

### 3. Compilation Optimization
```bash
# Release with optimization
zig build benchmark -Doptimize=ReleaseFast

# Small binary size
zig build benchmark -Doptimize=ReleaseSmall

# Debug with safety checks
zig build benchmark -Doptimize=Debug
```

## 🔍 Custom Profiling

### Creating Custom Benchmarks
```zig
const std = @import("std");
const ohlcv = @import("ohlcv");

fn benchmarkCustomIndicator(allocator: std.mem.Allocator, data_size: usize) !void {
    // Generate test data
    const test_data = try generateTestData(allocator, data_size);
    defer allocator.free(test_data);
    
    var series = try ohlcv.TimeSeries.fromSlice(allocator, test_data, false);
    defer series.deinit();

    // Timing
    const start = std.time.nanoTimestamp();
    
    // Your indicator calculation
    const indicator = ohlcv.SmaIndicator{ .u32_period = 20 };
    var result = try indicator.calculate(series, allocator);
    result.deinit();
    
    const end = std.time.nanoTimestamp();
    
    std.debug.print("Custom benchmark: {}ns\n", .{end - start});
}
```

### Memory Usage Tracking
```zig
var gpa = std.heap.GeneralPurposeAllocator(.{
    .verbose_log = true,  // Enable verbose logging
    .stack_trace_frames = 8,  // Stack traces for allocations
}){};
defer {
    const status = gpa.deinit();
    if (status == .leak) std.debug.print("Memory leaked!\n", .{});
}
```

## 📊 Continuous Profiling

### Automated Benchmarking
Create a script to run benchmarks regularly:

```bash
#!/bin/bash
# benchmark.sh
echo "Running OHLCV benchmarks..."
zig build benchmark > benchmark_results_$(date +%Y%m%d_%H%M%S).txt
zig build profile-memory > memory_profile_$(date +%Y%m%d_%H%M%S).txt
```

### Performance Regression Testing
```bash
# Store baseline performance
zig build benchmark | grep "ns/op" > performance_baseline.txt

# Compare against baseline
zig build benchmark | grep "ns/op" > performance_current.txt
diff performance_baseline.txt performance_current.txt
```

## 🎛️ Platform-Specific Tips

### macOS
- Use Instruments for detailed CPU/memory analysis
- Monitor with Activity Monitor for high-level metrics
- Use `sudo dtruss` for system call tracing

### Linux
- `perf` for CPU profiling
- `valgrind` for memory analysis
- `htop` for real-time monitoring

### Windows
- Use Performance Toolkit (WPT)
- Visual Studio Diagnostic Tools
- Windows Performance Monitor

## 📝 Best Practices

1. **Always use release builds** for performance benchmarking
2. **Run multiple iterations** to account for variance
3. **Use consistent test data** for reproducible results
4. **Profile on target hardware** - development machines may not reflect production
5. **Monitor system resources** during profiling
6. **Document findings** with specific configurations and conditions
7. **Version your benchmarks** to track performance over time

## 🚨 Common Pitfalls

- Running benchmarks on debug builds
- Not accounting for system load during profiling
- Comparing results across different hardware
- Ignoring memory fragmentation effects
- Profiling with insufficient data samples
- Not considering compiler optimization effects

## 📚 Additional Resources

- [Zig Performance Guide](https://ziglang.org/documentation/master/#Performance)
- [Systems Performance by Brendan Gregg](https://www.brendangregg.com/systems-performance-2nd-edition-book.html)
- [Intel VTune Profiler](https://www.intel.com/content/www/us/en/developer/tools/oneapi/vtune-profiler.html)
- [Apple Instruments User Guide](https://help.apple.com/instruments/mac/current/)