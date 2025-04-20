// ╔══════════════════════════════════════ OHLCV Public API ══════════════════════════════════════╗

// ┌──────────────────────────── Types ─────────────────────────────┐

pub const Row = @import("types/row.zig").Row;
pub const Bar = @import("types/bar.zig").Bar;

// └────────────────────────────────────────────────────────────────┘

// ┌─────────────────────────── Provider ───────────────────────────┐

pub const DataSet = @import("provider/provider.zig").DataSet;
pub const fetch = @import("provider/provider.zig").fetch;

// └────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── Parser ────────────────────────────┐

pub const ParseError = @import("types/errors.zig").ParseError;
pub const FetchError = @import("types/errors.zig").FetchError;
pub const parseCsv = @import("parser/parser.zig").parseCsv;
pub const parseCsvFast = @import("parser/parser.zig").parseCsvFast;

// └────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── Indicators ────────────────────────────┐

pub const indicators = @import("indicators/indicators.zig");

// └────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════════════╝
