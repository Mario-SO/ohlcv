# GitHub Actions Performance Monitoring

This repository includes automated performance monitoring through GitHub Actions to catch performance regressions early and track performance trends over time.

## 🚀 Available Workflows

### 1. Performance Benchmarks (`performance.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`  
- Daily at 2:00 UTC (scheduled)
- Manual dispatch

**What it does:**
- Runs comprehensive performance benchmarks
- Executes memory profiling
- Compares with previous runs when available
- Uploads detailed profiling data as artifacts
- Comments on PRs with performance results
- Checks for performance regressions (fails if >50% slower)

### 2. PR Performance Check (`performance-pr.yml`)

**Triggers:**
- Pull requests to `main` (opened, synchronized, reopened)

**What it does:**
- Benchmarks both PR branch and main branch
- Generates detailed performance comparison table
- Posts comparison as PR comment (updates existing comment)
- Fails CI if significant performance regression detected (>20% slower)
- Uses Python script for accurate delta calculations

### 3. Performance Monitoring (`performance-monitoring.yml`)

**Triggers:**
- Daily at 3:00 UTC (scheduled)
- Manual dispatch with configurable history period

**What it does:**
- Collects historical performance data
- Generates trend analysis with charts
- Tracks performance over time (up to 60 days)
- Creates GitHub issues for significant performance degradation
- Maintains performance history artifacts

## 📊 What Gets Monitored

### Performance Metrics
- **SMA-20**: Simple Moving Average (20 period)
- **EMA-20**: Exponential Moving Average (20 period)  
- **RSI-14**: Relative Strength Index (14 period)
- **Bollinger-20**: Bollinger Bands (20 period)
- **MACD**: Moving Average Convergence Divergence
- **ATR-14**: Average True Range (14 period)

### Test Data Sizes
- **1,000 data points**: Small dataset performance
- **10,000 data points**: Medium dataset performance

### Memory Metrics
- Memory usage per operation
- Memory leaks detection
- Peak memory consumption
- Memory efficiency trends

## 📈 Performance Reports

### PR Comments
Every PR gets an automatic performance comparison comment showing:

```markdown
# 📊 Performance Benchmark Results

## Benchmark Results
📊 Dataset: 1000 data points
SMA-20:           0.004 ms
EMA-20:           0.006 ms
RSI-14:           0.007 ms
...

## Performance Comparison
| Indicator | Main (ms) | PR (ms) | Delta | Change | Status |
|-----------|-----------|---------|-------|--------|--------|
| SMA-20    |     0.004 |   0.005 | +0.001 |  +25.0% | ⚠️ SLOWER |
| EMA-20    |     0.006 |   0.006 |  0.000 |   0.0% | ✅ OK |
...
```

### Trend Analysis
Daily monitoring generates trend reports with:
- Performance changes over time
- Visual charts showing trends
- Alerts for significant degradations
- Historical data preservation

## ⚡ Performance Thresholds

### CI/CD Failure Thresholds
- **Major regression**: >50% performance loss (fails CI)
- **Significant regression**: >20% performance loss (fails PR check)
- **Minor regression**: 5-20% performance loss (warning)
- **Acceptable variance**: <5% change (passes)

### Trend Monitoring Thresholds
- **Stable**: <2% change over time
- **Degradation alert**: >25% degradation creates GitHub issue
- **Improvement tracking**: >10% improvement noted in reports

## 🔧 Configuration

### Manual Workflow Dispatch
You can manually trigger performance monitoring:

1. Go to **Actions** tab in GitHub
2. Select **Performance Monitoring** workflow  
3. Click **Run workflow**
4. Optional: Set number of days for history analysis

### Customizing Thresholds
Edit the workflow files to adjust performance thresholds:

```yaml
# In performance-pr.yml
if change_pct > 20:  # Adjust regression threshold
    status = "❌ SLOWER"
```

### Adding New Indicators
To monitor additional indicators:

1. Add the indicator to benchmark suite
2. Update the regex patterns in workflows:
   ```python
   pattern = r'(SMA-\d+|EMA-\d+|RSI-\d+|NEW_INDICATOR):\s+([0-9.]+)\s+ms'
   ```

## 📁 Artifacts and Data

### Artifact Retention
- **Benchmark results**: 30 days
- **Detailed profiling**: 7 days  
- **Performance trends**: 90 days
- **Performance history**: 90 days (rolling 60-day dataset)

### Artifact Contents
- `benchmark_latest.txt`: Latest benchmark results
- `memory_profile_latest.txt`: Latest memory profile
- `PERFORMANCE_SUMMARY.md`: Formatted summary report
- `performance_trends.png`: Visual trend charts
- `performance_history.json`: Historical data for analysis

## 🛠️ Local Development

### Running Benchmarks Locally
```bash
# Quick benchmarks
zig build benchmark

# Memory profiling  
zig build profile-memory

# Full profiling suite
./scripts/profile.sh all

# Compare with previous run
./scripts/profile.sh compare
```

### Testing Workflow Changes
1. Make changes to workflow files
2. Push to a feature branch
3. Create PR to see performance comparison in action
4. Monitor GitHub Actions for successful execution

## 🚨 Troubleshooting

### Common Issues

**Workflow fails with "No benchmark results"**
- Check that `zig build benchmark` succeeds locally
- Verify benchmark executables are building correctly
- Check for missing dependencies in CI environment

**Performance comparison shows "No previous data"**
- This is normal for the first run after setup
- Subsequent runs will have comparison data
- Historical data builds up over time

**False positive performance regressions**
- CI environments can have variable performance
- Consider adjusting thresholds if too sensitive
- Look for consistent trends rather than single-run spikes

### Debug Information
Each workflow provides detailed logs including:
- Build output and errors
- Benchmark execution results  
- File parsing and comparison details
- Artifact upload/download status

## 📚 Best Practices

1. **Review performance comments** on every PR
2. **Investigate significant regressions** before merging
3. **Monitor trend reports** for gradual degradation
4. **Update benchmarks** when adding new features
5. **Keep thresholds realistic** based on your performance requirements
6. **Archive important results** before major refactoring

This automated performance monitoring helps maintain the high performance standards of the OHLCV library while providing visibility into performance impacts of code changes.