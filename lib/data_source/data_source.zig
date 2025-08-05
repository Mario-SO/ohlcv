// ╔════════════════════════════════════ Data Source Interface ════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Interface for data sources - allows custom implementations
pub const DataSource = struct {
    const Self = @This();

    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        fetchFn: *const fn (ptr: *anyopaque, allocator: Allocator) anyerror![]u8,
        deinitFn: *const fn (ptr: *anyopaque) void,
    };

    /// Fetch data from the source
    pub fn fetch(self: Self, allocator: Allocator) ![]u8 {
        return self.vtable.fetchFn(self.ptr, allocator);
    }

    /// Clean up resources
    pub fn deinit(self: Self) void {
        self.vtable.deinitFn(self.ptr);
    }
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
