# OHLCV Library Tests

## Test Structure

```
test/
├── unit/                    # Unit tests for individual components
│   ├── test_time_series.zig    # TimeSeries container tests
│   ├── test_data_sources.zig   # DataSource interface tests
│   ├── test_csv_parser.zig     # CSV parser tests
│   └── test_indicators.zig     # Technical indicator tests
├── integration/             # Integration tests
│   └── test_full_workflow.zig  # End-to-end workflow tests
├── fixtures/               # Test data files
│   └── sample_data.csv        # Sample CSV for testing
├── test_helpers.zig        # Shared test utilities
├── test_all.zig           # Test runner
└── README.md              # This file
```

## Running Tests

### Run all tests:
```bash
zig build test
```

### Run tests with verbose output:
```bash
zig build test --verbose
```

### Run specific test file:
```bash
zig test test/unit/test_time_series.zig -I lib --dep ohlcv -Mohlcv=lib/ohlcv.zig
```

## Test Coverage

### Unit Tests

1. **TimeSeries Tests** (`test_time_series.zig`)
   - ✅ Empty series initialization
   - ✅ Creating from slice
   - ✅ Time-based slicing
   - ✅ Filtering operations
   - ✅ Sorting by timestamp
   - ✅ Iterator functionality
   - ✅ Map transformations
   - ✅ Extracting close prices

2. **DataSource Tests** (`test_data_sources.zig`)
   - ✅ Memory data source
   - ✅ File data source
   - ✅ Interface polymorphism
   - ✅ Multiple fetches

3. **CSV Parser Tests** (`test_csv_parser.zig`)
   - ✅ Valid CSV parsing
   - ✅ Header skipping
   - ✅ Empty line handling
   - ✅ Invalid row skipping
   - ✅ Data validation
   - ✅ Pre-epoch date handling
   - ✅ Various line endings (CRLF, LF, CR)
   - ⚡ Fast parser primitives
   - 🔄 Streaming parser for large files

4. **Indicator Tests** (`test_indicators.zig`)
   - ✅ **All 37 Indicators fully tested**:
     - **Trend**: SMA, EMA, WMA, ADX, DMI, Parabolic SAR
     - **Momentum**: RSI, MACD, Stochastic, Stochastic RSI, Ultimate Oscillator, TRIX, ROC, Momentum, Williams %R
     - **Volatility**: ATR, Bollinger Bands, Keltner Channels, Donchian Channels, Price Channels
     - **Volume**: OBV, MFI, CMF, Force Index, Accumulation/Distribution, VWAP, CCI
     - **Advanced**: Ichimoku Cloud, Heikin Ashi, Pivot Points, Elder Ray, Aroon, Zig Zag
   - ✅ Multi-line results (MACD, Bollinger Bands, Stochastic, etc.)
   - ✅ Edge cases (period=0, insufficient data)
   - ✅ All gains/losses scenarios
   - ✅ Timestamp alignment
   - ✅ Comprehensive test coverage for all indicators

5. **Memory Management Tests** 
   - 🆕 Memory pool allocation/deallocation
   - 🆕 IndicatorArena batch operations
   - 🆕 Memory leak detection

### Integration Tests

1. **Full Workflow Tests** (`test_full_workflow.zig`)
   - ✅ Complete data pipeline
   - ✅ Multiple data source comparison
   - ✅ Data integrity preservation
   - 🆕 Streaming parser integration
   - 🆕 Memory pool integration

## Test Helpers

The `test_helpers.zig` module provides utilities:

- `createSampleRows()` - Generate test OHLCV data
- `rowsEqual()` - Compare OHLCV rows with tolerance
- `floatEquals()` - Compare floats with epsilon
- `rowsToCsv()` - Convert rows to CSV format

## Performance Testing

### Benchmarks Available:
```bash
zig build benchmark                # Basic performance test
zig build benchmark-performance     # Comprehensive indicator benchmarks
zig build benchmark-streaming       # Streaming vs standard parser comparison
zig build profile-memory           # Memory usage profiling
```

### Performance Metrics:
- Execution time (ms)
- Operations per second
- Memory allocations/deallocations
- Peak memory usage
- Cache efficiency

## CI/CD Integration

Tests run automatically on:
- Every push to `main` or `develop`
- Every pull request
- Daily performance regression tests
- Memory leak detection in debug builds
- Multiple platforms (Ubuntu, macOS, Windows)

See `.github/workflows/test.yml` for details.

## Adding New Tests

1. Create test file in appropriate directory
2. Follow naming convention: `test_<component>.zig`
3. Use boxed comments and intelligent box labels for organization
4. Import test helpers if needed
5. Add to `test_all.zig` imports

Example test structure:
```zig
// ╔══════════════════════ Component Tests ══════════════════════╗

const std = @import("std");
const testing = std.testing;
const ohlcv = @import("ohlcv");

test "Component does X correctly" {
    const allocator = testing.allocator;
    
    // Test implementation
    try testing.expect(condition);
}

// ╚════════════════════════════════════════════════════════════╝
```