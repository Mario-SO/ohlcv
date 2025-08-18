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

*   [x] **VWAP (Volume Weighted Average Price)** - `VwapIndicator`
    - Cumulative average price weighted by volume using typical price
    - No parameters

*   [x] **CCI (Commodity Channel Index)** - `CciIndicator`
    - (TP - SMA(TP)) / (0.015 * MeanDeviation), where TP is typical price
    - Default period: 20, configurable

*   [x] **OBV (On-Balance Volume)** - `ObvIndicator`
    - Cumulative volume added/subtracted based on price moves
    - No parameters

*   [x] **Donchian Channels** - `DonchianChannelsIndicator`
    - Upper: highest high, Lower: lowest low, Middle: average of upper/lower
    - Default period: 20, configurable

*   [x] **Aroon Indicator** - `AroonIndicator`
    - Measures time since highest high/lowest low (Up/Down lines)
    - Default period: 25, configurable

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

## ✅ All Indicators Now Implemented!

### Recently Added Indicators:

*   [x] **ADX (Average Directional Index)** - `AdxIndicator`
    - Measures trend strength with +DI and -DI components
    - Default period: 14, configurable

*   [x] **CMF (Chaikin Money Flow)** - `CmfIndicator`
    - Volume-weighted average of accumulation/distribution
    - Default period: 20, configurable

*   [x] **MFI (Money Flow Index)** - `MfiIndicator`
    - RSI-type oscillator using price and volume
    - Default period: 14, configurable

*   [x] **Parabolic SAR** - `ParabolicSarIndicator`
    - Trend-following indicator, trailing stop
    - Default AF: 0.02, increment: 0.02, max: 0.20, all configurable

*   [x] **Pivot Points** - `PivotPointsIndicator`
    - Support/resistance levels (P, S1, S2, R1, R2) based on OHLC
    - No parameters

*   [x] **Keltner Channels** - `KeltnerChannelsIndicator`
    - Volatility-based envelopes set above/below EMA using ATR
    - Default EMA period: 20, ATR period: 10, multiplier: 2.0, all configurable

*   [x] **TRIX (Triple Exponential Average)** - `TrixIndicator`
    - Oscillator showing percent rate of change of a triple EMA
    - Default period: 14, configurable

*   [x] **Ultimate Oscillator** - `UltimateOscillatorIndicator`
    - Combines short, medium, and long-term price action
    - Default periods: 7, 14, 28, all configurable

*   [x] **DMI (Directional Movement Index)** - `DmiIndicator`
    - Includes ADX, +DI, and -DI components for trend analysis
    - Default period: 14, configurable

*   [x] **Elder Ray Index** - `ElderRayIndicator`
    - Bull and bear power based on EMA
    - Default EMA period: 13, configurable

*   [x] **Stochastic RSI** - `StochasticRsiIndicator`
    - RSI applied to RSI values, more sensitive
    - Default RSI period: 14, stochastic period: 14, both configurable

*   [x] **Ichimoku Cloud** - `IchimokuCloudIndicator`
    - Multiple averages, support/resistance, trend and momentum
    - Default periods: tenkan=9, kijun=26, senkou=52, displacement=26, all configurable

*   [x] **Heikin Ashi Candles** - `HeikinAshiIndicator`
    - Smoothed candlestick representation
    - No parameters

*   [x] **Price Channels** - `PriceChannelsIndicator`
    - High and low price over a period with middle channel
    - Default period: 20, configurable

*   [x] **Force Index** - `ForceIndexIndicator`
    - Combines price and volume to show buying/selling pressure
    - Default EMA period: 13, configurable

*   [x] **Accumulation/Distribution Line** - `AccumulationDistributionIndicator`
    - Measures supply and demand using price and volume
    - No parameters

*   [x] **Zig Zag Indicator** - `ZigZagIndicator`
    - Filters out smaller price movements to identify trends
    - Default threshold: 5.0%, configurable
