# Performance Monitoring Guide

Last Updated: 2025-08-18

## 🎯 Simplified Performance Monitoring

This repository uses a streamlined approach to performance monitoring with just 2 workflows that handle performance tracking.

## 📊 Performance Workflows

### 1. **CI Workflow** (`ci.yml`)
**When it runs**: Every push and PR
**Performance features**:
- ✅ Quick benchmark on PRs
- ✅ Compares PR vs main branch
- ✅ Fails if >50% performance regression
- ✅ Auto-comments results on PRs
- **Runtime**: ~2-3 minutes

### 2. **Performance Tracking** (`performance-tracking.yml`)
**When it runs**: Weekly (Sunday 2 AM UTC) or manual
**Performance features**:
- 📊 Full benchmark suite (all indicators)
- 📈 Historical tracking (keeps last 10 results)
- 💾 Comprehensive performance analysis
- 🔄 Streaming vs standard parser comparison
- **Runtime**: ~5 minutes

## 📈 What Gets Monitored

### Core Indicators (Quick Check - Every PR)
- **SMA-20**: Simple Moving Average
- **EMA-20**: Exponential Moving Average  
- **RSI-14**: Relative Strength Index
- **Bollinger-20**: Bollinger Bands
- **MACD**: Moving Average Convergence Divergence
- **ATR-14**: Average True Range

### Full Suite (Weekly + Manual)
All 33 indicators including:
- **Trend**: ADX, DMI, Parabolic SAR, etc.
- **Momentum**: Stochastic, Williams %R, TRIX, etc.
- **Volatility**: Keltner Channels, Donchian Channels, etc.
- **Volume**: OBV, MFI, CMF, Force Index, etc.
- **Advanced**: Ichimoku Cloud, Pivot Points, etc.

### Dataset Sizes Tested
- 1,000 rows (small)
- 10,000 rows (medium)
- 50,000 rows (large)

## 🚀 Performance Standards

### PR Performance Check
Every PR automatically gets checked:
```
Performance ratio: 1.2 (PR/main)
✅ Performance acceptable (<1.5x slower)
```

**Thresholds**:
- ✅ **Pass**: <50% slower than main
- ❌ **Fail**: >50% slower than main

### Weekly Performance Tracking
Comprehensive analysis includes:
- Parser throughput (rows/ms)
- Memory usage patterns
- Indicator calculation times
- Streaming vs standard comparison

## 📋 PR Comment Example

Every PR receives an automatic comment:
```markdown
## 🚀 CI Results

### Performance (1000 points)
```
SMA-20:       0.004 ms
EMA-20:       0.005 ms
RSI-14:       0.006 ms
Bollinger-20: 0.012 ms
MACD:         0.024 ms
ATR-14:       0.010 ms
```

✅ All checks passed
```

## 🛠️ Running Benchmarks Locally

```bash
# Quick benchmark (mimics CI)
zig build benchmark

# Full performance suite
zig build benchmark-performance

# Streaming comparison
zig build benchmark-streaming

# Memory profiling
zig build profile-memory
```

## 📁 Performance Artifacts

### What's Stored
- **CI Results**: Not stored (shown in PR comments only)
- **Weekly Results**: Last 10 benchmark runs
- **Retention**: 30 days for artifacts

### Artifact Contents
- `latest.txt`: Most recent benchmark results
- `benchmark_YYYYMMDD_HHMMSS.txt`: Timestamped results
- `SUMMARY.md`: Formatted performance summary

## 🔧 Manual Performance Testing

### Trigger Comprehensive Benchmark
1. Go to **Actions** tab
2. Select **Performance Tracking**
3. Click **Run workflow**
4. Check "Run comprehensive benchmarks" for full suite

### View Historical Results
1. Go to **Actions** tab
2. Select a previous **Performance Tracking** run
3. Download artifacts from bottom of page

## ⚡ Performance Tips

### For Contributors
1. **Before submitting PR**: Run `zig build benchmark` locally
2. **Check PR comment**: Review automated performance results
3. **If regression detected**: Optimize before merge

### For Maintainers
1. **Weekly reports**: Check Sunday performance runs
2. **Manual triggers**: Run comprehensive tests before releases
3. **Historical data**: Download artifacts for trend analysis

## 🚨 Troubleshooting

### "Performance regression detected"
- PR is >50% slower than main
- Run locally to verify: `zig build benchmark`
- Profile specific indicators if needed

### "Could not compare performance"
- Benchmark may have failed to run
- Check that tests pass: `zig build test`
- Verify benchmarks build: `zig build benchmark`

### Missing historical data
- First runs won't have comparison data
- Weekly runs build up history over time
- Manual runs can fill gaps

## 📊 Interpreting Results

### Parser Performance
```
Standard Parser:
  Throughput: 16,129 rows/ms  ← Good (>15,000)
  
Streaming Parser:
  Throughput: 347 rows/ms     ← Expected (trades speed for memory)
```

### Memory Usage
```
Single indicators: ~16 KB per 1K rows
Multi-line indicators: ~47 KB per 1K rows
Streaming: 4 KB constant (regardless of size)
```

## 🎯 Performance Goals

- **Parser**: >15,000 rows/ms throughput
- **SMA-20**: <0.03 ms for 1K rows
- **Memory**: No leaks detected
- **Regression**: <5% variance acceptable

## 📈 Continuous Improvement

The simplified monitoring system:
1. **Catches regressions** immediately on PRs
2. **Tracks trends** with weekly snapshots
3. **Enables investigation** with comprehensive benchmarks
4. **Maintains standards** with automated checks

---

*For workflow implementation details, see `.github/workflows/`*