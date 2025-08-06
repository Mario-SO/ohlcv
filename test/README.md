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

4. **Indicator Tests** (`test_indicators.zig`)
   - ✅ SMA calculation accuracy
   - ✅ EMA calculation accuracy
   - ✅ RSI calculation accuracy
   - ✅ MACD multi-line results
   - ✅ Bollinger Bands three-band results
   - ✅ ATR volatility calculation
   - ✅ Stochastic %K and %D lines
   - ✅ Williams %R oscillator
   - ✅ WMA weighted calculations
   - ✅ ROC percentage changes
   - ✅ Momentum price differences
   - ✅ Edge cases (period=0, insufficient data)
   - ✅ All gains/losses scenarios
   - ✅ Timestamp alignment

### Integration Tests

1. **Full Workflow Tests** (`test_full_workflow.zig`)
   - ✅ Complete data pipeline
   - ✅ Multiple data source comparison
   - ✅ Data integrity preservation

## Test Helpers

The `test_helpers.zig` module provides utilities:

- `createSampleRows()` - Generate test OHLCV data
- `rowsEqual()` - Compare OHLCV rows with tolerance
- `floatEquals()` - Compare floats with epsilon
- `rowsToCsv()` - Convert rows to CSV format

## CI/CD Integration

Tests run automatically on:
- Every push to `main` or `develop`
- Every pull request
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