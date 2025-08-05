// ╔══════════════════════════════════════ Memory Data Source ══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const DataSource = @import("data_source.zig").DataSource;

pub const MemoryDataSource = struct {
    const Self = @This();

    allocator: Allocator,
    arr_data: []const u8,
    b_owns_data: bool,

    /// Initialize memory data source with data
    pub fn init(allocator: Allocator, data: []const u8, owns_data: bool) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .arr_data = if (owns_data) data else try allocator.dupe(u8, data),
            .b_owns_data = true,
        };
        return self;
    }

    /// Convert to DataSource interface
    pub fn dataSource(self: *Self) DataSource {
        return .{
            .ptr = self,
            .vtable = &.{
                .fetchFn = fetchImpl,
                .deinitFn = deinitImpl,
            },
        };
    }

    fn fetchImpl(ptr: *anyopaque, allocator: Allocator) anyerror![]u8 {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return try allocator.dupe(u8, self.arr_data);
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        if (self.b_owns_data) {
            self.allocator.free(self.arr_data);
        }
        self.allocator.destroy(self);
    }
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════════════╝
