// ╔══════════════════════════════════════ HTTP Data Source ═══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;
const DataSource = @import("data_source.zig").DataSource;
const ArrayList = std.array_list.Managed;

pub const HttpDataSource = struct {
    const Self = @This();

    allocator: Allocator,
    str_url: []const u8,

    /// Initialize HTTP data source with URL
    pub fn init(allocator: Allocator, url: []const u8) !*Self {
        const self = try allocator.create(Self);
        const url_copy = try allocator.dupe(u8, url);
        self.* = .{
            .allocator = allocator,
            .str_url = url_copy,
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

        var client = std.http.Client{ .allocator = allocator };
        defer client.deinit();

        var response_body = ArrayList(u8).init(allocator);
        errdefer response_body.deinit();

        var writer = response_body.writer();
        var writer_buffer: [4096]u8 = undefined;
        var writer_adapter = writer.adaptToNewApi(writer_buffer[0..]);

        const response = try client.fetch(.{
            .location = .{ .url = self.str_url },
            .response_writer = &writer_adapter.new_interface,
        });

        _ = response;
        if (writer_adapter.err) |err| return err;
        return try response_body.toOwnedSlice();
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.allocator.free(self.str_url);
        self.allocator.destroy(self);
    }
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
