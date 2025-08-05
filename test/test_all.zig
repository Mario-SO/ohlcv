// ╔═════════════════════════════════════════ Test Runner ═════════════════════════════════════════╗

const std = @import("std");

// Import all test files
pub const test_time_series = @import("unit/test_time_series.zig");
pub const test_data_sources = @import("unit/test_data_sources.zig");
pub const test_csv_parser = @import("unit/test_csv_parser.zig");
pub const test_indicators = @import("unit/test_indicators.zig");
pub const test_full_workflow = @import("integration/test_full_workflow.zig");

test {
    // Reference all test containers to ensure they run
    std.testing.refAllDecls(@This());
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
