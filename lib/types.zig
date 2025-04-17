// ╔══════════════════════════════════════ Types ══════════════════════════════════════╗

/// Immutable in‑memory representation of one OHLCV full csv row.
pub const Row = struct {
    ts: u64,
    o: f64,
    h: f64,
    l: f64,
    c: f64,
    v: u64,
};

/// Immutable in‑memory representation of one OHLC bar.
pub const Bar = struct {
    ts: u64,
    o: f64,
    h: f64,
    l: f64,
    c: f64,
};

// ╚══════════════════════════════════════════════════════════════════════════════════╝
