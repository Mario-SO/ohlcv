/// Immutable in‑memory representation of one OHLC bar.
pub const Bar = struct {
    ts: u64,
    o: f64,
    h: f64,
    l: f64,
    c: f64,
};
