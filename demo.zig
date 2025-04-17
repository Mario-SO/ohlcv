const std = @import("std");
const print = std.debug.print;

const ohlcv = @import("ohlcv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const alloc = gpa.allocator();
    const rows = try ohlcv.fetch(.sp500, alloc);

    print("Row struct size = {} bytes\n", .{@sizeOf(ohlcv.Row)});
    print("Rows slice size = {} bytes\n", .{rows.len * @sizeOf(ohlcv.Row)});
}
