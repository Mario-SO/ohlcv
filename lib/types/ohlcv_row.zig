// ╔══════════════════════════════════════ OHLCV Row Type ══════════════════════════════════════╗

/// Represents a single OHLCV data point with volume
pub const OhlcvRow = struct {
    u64_timestamp: u64, // Unix timestamp in seconds
    f64_open: f64,      // Opening price
    f64_high: f64,      // Highest price
    f64_low: f64,       // Lowest price
    f64_close: f64,     // Closing price
    u64_volume: u64,    // Trading volume
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════╝