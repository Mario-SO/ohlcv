// ╔══════════════════════════════════════ OHLCV Public API ══════════════════════════════════════╗

// ┌──────────────────────────── Types ────────────────────────────┐

pub const Row = @import("types.zig").Row;
pub const Bar = @import("types.zig").Bar;

// └──────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── Errors ──────────────────────────┐

pub const ParseError = @import("errors.zig").ParseError;
pub const FetchError = @import("errors.zig").FetchError;

// └──────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── DataSet & Fetch ────────────────────────────┐

pub const DataSet = @import("fetch.zig").DataSet;
pub const fetch = @import("fetch.zig").fetch;

// └─────────────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── Parsing ────────────────────────────┐

pub const parseCsv = @import("parse.zig").parseCsv;
pub const parseCsvFast = @import("parse.zig").parseCsvFast;
pub const parseFileCsv = @import("parse.zig").parseFileCsv;
pub const parseStringCsv = @import("parse.zig").parseStringCsv;

// └─────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════════════════╝
