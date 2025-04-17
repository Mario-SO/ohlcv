// ╔══════════════════════════════════════ OHLCV Public API ══════════════════════════════════════╗

// ┌──────────────────────────── Types ─────────────────────────────┐

pub const Row = @import("core/types/row.zig").Row;
pub const Bar = @import("core/types/bar.zig").Bar;

// └────────────────────────────────────────────────────────────────┘

// ┌─────────────────────────── Provider ───────────────────────────┐

pub const fetch = @import("core/provider/provider.zig").fetch;

// └────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── Parser ────────────────────────────┐

pub const ParseError = @import("core/types/errors.zig").ParseError;
pub const FetchError = @import("core/types/errors.zig").FetchError;
pub const parseCsv = @import("core/parser/parser.zig").parseCsv;
pub const parseCsvFast = @import("core/parser/parser.zig").parseCsvFast;

// └────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════════════╝
