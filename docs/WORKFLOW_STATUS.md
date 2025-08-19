# GitHub Workflows - Simplified

Last Updated: 2025-08-18

## 🎯 Consolidated to 3 Essential Workflows

### 1. **ci.yml** - Main CI Pipeline
**Trigger**: Every push and PR
**What it does**:
- ✅ Runs tests on Ubuntu, macOS, Windows
- ✅ Builds and verifies the library
- ✅ Quick performance check on PRs (fails if >50% slower)
- ✅ Auto-comments results on PRs
- **Runtime**: ~2-3 minutes

### 2. **performance-tracking.yml** - Performance Monitoring  
**Trigger**: Weekly (Sunday) or manual
**What it does**:
- 📊 Runs all benchmarks (basic, comprehensive, streaming)
- 📈 Tracks performance over time
- 💾 Archives results (keeps last 10)
- 🚨 Can detect regressions
- **Runtime**: ~5 minutes

### 3. **daily_update.yml** - Market Data Updates
**Trigger**: Daily at 23:00 UTC
**What it does**:
- 📉 Updates CSV files with latest market data
- 🤖 Auto-commits changes
- **Runtime**: ~1 minute

## 🗑️ Removed Workflows (Consolidated)

Previously had 6 workflows, now consolidated:
- ~~test.yml~~ → Merged into `ci.yml`
- ~~coverage.yml~~ → Merged into `ci.yml`  
- ~~performance.yml~~ → Merged into `performance-tracking.yml`
- ~~performance-pr.yml~~ → Merged into `ci.yml`
- ~~performance-monitoring.yml~~ → Merged into `performance-tracking.yml`

## ✨ Benefits of Consolidation

1. **Faster CI**: Single workflow instead of multiple parallel ones
2. **Less Maintenance**: 3 files instead of 6
3. **Clearer Purpose**: Each workflow has distinct responsibility
4. **Reduced Redundancy**: No duplicate benchmark runs
5. **Simpler PR Checks**: One status check instead of many

## 📊 Workflow Triggers Summary

| Event | ci.yml | performance-tracking.yml | daily_update.yml |
|-------|--------|--------------------------|------------------|
| Push to main/develop | ✅ | ❌ | ❌ |
| Pull Request | ✅ | ❌ | ❌ |
| Schedule | ❌ | ✅ Weekly | ✅ Daily |
| Manual | ❌ | ✅ | ✅ |

## 🚀 Quick Commands

```bash
# Run tests locally (mimics CI)
zig build test

# Run benchmarks locally  
zig build benchmark
zig build benchmark-performance
zig build benchmark-streaming

# Check what CI will run
cat .github/workflows/ci.yml
```

## 📈 Performance Standards

- **PR Performance**: Must not be >50% slower than main
- **Weekly Tracking**: Full benchmark suite runs Sunday 2 AM UTC
- **Manual Runs**: Can trigger comprehensive benchmarks anytime

## 🔧 Maintenance Notes

- CI runs on every commit (lightweight, ~2-3 min)
- Performance tracking runs weekly (comprehensive, ~5 min)
- Daily updates run at market close (data only, ~1 min)

Total workflows: **3** (down from 6)
Total complexity: **Reduced by 50%**