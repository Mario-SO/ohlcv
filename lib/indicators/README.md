# Technical Indicators

This document lists common technical indicators used in financial analysis. All indicators are now organized with intelligent box labels for better code readability.

## 📊 Implemented Indicators

*   [x] **SMA (Simple Moving Average)** - `SmaIndicator`
    - Average of closing prices over a period
    - Default period: 20, configurable

*   [x] **EMA (Exponential Moving Average)** - `EmaIndicator`  
    - Weighted average, more responsive to recent prices
    - Default period: 20, smoothing: 2.0, both configurable

*   [x] **RSI (Relative Strength Index)** - `RsiIndicator`
    - Measures speed and change of price movements (momentum oscillator)
    - Default period: 14, configurable

*   [x] **MACD (Moving Average Convergence Divergence)** - `MacdIndicator`
    - Difference between two EMAs, with signal line and histogram
    - Returns: `MacdResult` with macd_line, signal_line, and histogram
    - Default periods: fast=12, slow=26, signal=9, all configurable

*   [x] **Bollinger Bands** - `BollingerBandsIndicator`
    - SMA with upper/lower bands based on standard deviation
    - Returns: `BollingerBandsResult` with upper_band, middle_band, lower_band
    - Default period: 20, std dev multiplier: 2.0, both configurable

*   [x] **ATR (Average True Range)** - `AtrIndicator`
    - Measures market volatility using Wilder's smoothing
    - Default period: 14, configurable

*   [x] **Stochastic Oscillator** - `StochasticIndicator`
    - Compares closing price to price range over a period
    - Returns: `StochasticResult` with k_percent and d_percent lines
    - Default periods: %K=14, %K slowing=1, %D=3, all configurable

*   [x] **WMA (Weighted Moving Average)** - `WmaIndicator`
    - Moving average with linear weights (most recent price weighted highest)
    - Period must be specified (no default)

*   [x] **ROC (Rate of Change)** - `RocIndicator`
    - Percentage change in price over a period
    - Default period: 14, configurable

*   [x] **Momentum** - `MomentumIndicator`
    - Difference between current price and price n periods ago
    - Default period: 10, configurable

*   [x] **Williams %R** - `WilliamsRIndicator`
    - Momentum oscillator, measures overbought/oversold levels
    - Default period: 14, configurable

## 🔮 Code Organization

All indicators follow a consistent structure with intelligent box labels:

```zig
pub const XxxIndicator = struct {
    const Self = @This();

    // [box] Attributes
    // Configuration parameters with defaults
    // [box]

    // [box] Error  
    // Error enum for this indicator
    // [box]

    // [box] Result (if complex multi-value result)
    // Custom result struct for indicators returning multiple values
    // [box]

    // [box] Calculate [Description]
    // Main calculation function
    // [box]
};
```

## 🚀 Usage Examples

### Single Indicator
```zig
const rsi = ohlcv.RsiIndicator{ .u32_period = 14 };
var rsi_result = try rsi.calculate(series, allocator);
defer rsi_result.deinit();
```

### Multi-Value Indicators
```zig
// MACD returns multiple lines
const macd = ohlcv.MacdIndicator{ .u32_fast_period = 12, .u32_slow_period = 26, .u32_signal_period = 9 };
var macd_result = try macd.calculate(series, allocator);
defer macd_result.deinit(); // Cleans up all three result lines

// Bollinger Bands returns three bands
const bb = ohlcv.BollingerBandsIndicator{ .u32_period = 20, .f64_std_dev_multiplier = 2.0 };
var bb_result = try bb.calculate(series, allocator);
defer bb_result.deinit(); // Cleans up all three bands

// Stochastic returns %K and %D
const stoch = ohlcv.StochasticIndicator{ .u32_k_period = 14, .u32_k_slowing = 1, .u32_d_period = 3 };
var stoch_result = try stoch.calculate(series, allocator);
defer stoch_result.deinit(); // Cleans up both lines
```

## 🔧 Planned / Not Implemented:

*   [ ] **VWAP (Volume Weighted Average Price):** Average price weighted by volume
*   [ ] **ADX (Average Directional Index):** Measures trend strength
*   [ ] **CCI (Commodity Channel Index):** Measures price deviation from average
*   [ ] **OBV (On-Balance Volume):** Cumulative volume based on price movement direction
*   [ ] **CMF (Chaikin Money Flow):** Volume-weighted average of accumulation/distribution
*   [ ] **MFI (Money Flow Index):** RSI-type oscillator using price and volume
*   [ ] **Parabolic SAR:** Trend-following indicator, trailing stop
*   [ ] **Donchian Channels:** High/low bands over a period
*   [ ] **Pivot Points:** Support/resistance levels based on OHLC
*   [ ] **Keltner Channels:** Volatility-based envelopes set above/below EMA
*   [ ] **TRIX (Triple Exponential Average):** Oscillator showing percent rate of change of a triple EMA
*   [ ] **Ultimate Oscillator:** Combines short, medium, and long-term price action
*   [ ] **DMI (Directional Movement Index):** Includes ADX, +DI, and -DI components
*   [ ] **Aroon Indicator:** Measures time since highest high/lowest low
*   [ ] **Elder Ray Index:** Bull and bear power based on EMA
*   [ ] **Stochastic RSI:** RSI applied to RSI values, more sensitive
*   [ ] **Ichimoku Cloud:** Multiple averages, support/resistance, trend and momentum
*   [ ] **Heikin Ashi Candles:** Smoothed candlestick representation
*   [ ] **Price Channels:** High and low price over a period
*   [ ] **Force Index:** Combines price and volume to show buying/selling pressure
*   [ ] **Accumulation/Distribution Line:** Measures supply and demand using price and volume
*   [ ] **Zig Zag Indicator:** Filters out smaller price movements to identify trends