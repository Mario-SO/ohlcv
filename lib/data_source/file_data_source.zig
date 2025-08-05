// ╔══════════════════════════════════════ File Data Source ═══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const DataSource = @import("data_source.zig").DataSource;

pub const FileDataSource = struct {
    const Self = @This();

    allocator: Allocator,
    str_path: []const u8,

    /// Initialize file data source with path
    pub fn init(allocator: Allocator, path: []const u8) !*Self {
        const self = try allocator.create(Self);
        const path_copy = try allocator.dupe(u8, path);
        self.* = .{
            .allocator = allocator,
            .str_path = path_copy,
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
        const file = try std.fs.cwd().openFile(self.str_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const contents = try allocator.alloc(u8, file_size);
        _ = try file.read(contents);

        return contents;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.allocator.free(self.str_path);
        self.allocator.destroy(self);
    }
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
