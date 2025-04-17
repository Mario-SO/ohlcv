// ╔══════════════════════════════════════ Parser Barrel ══════════════════════════════════════╗

const entry = @import("entry.zig");
const Row = @import("../core.zig").Row;

pub const parseCsv = entry.parseCsv;
pub const parseCsvFast = entry.parseCsvFast;

// ╚══════════════════════════════════════════════════════════════════════════════════════════╝
