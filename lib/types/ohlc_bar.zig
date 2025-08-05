// ╔══════════════════════════════════════ OHLC Bar Type ══════════════════════════════════════╗

/// Represents OHLC data without volume (used for indicator results)
pub const OhlcBar = struct {
    u64_timestamp: u64, // Unix timestamp in seconds
    f64_open: f64,      // Opening price or indicator value
    f64_high: f64,      // Highest price or upper band
    f64_low: f64,       // Lowest price or lower band
    f64_close: f64,     // Closing price or primary indicator value
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════╝