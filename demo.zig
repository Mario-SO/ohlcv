const std = @import("std");
const print = std.debug.print;
const ohlcv = @import("lib/ohlcv.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    // Fetch S&P 500 data
    const rows = try ohlcv.fetch(.sp500, alloc);
    defer alloc.free(rows); // Remember to free the allocated memory

    std.debug.print("Fetched {d} rows of data.\n", .{rows.len});

    // Print the first 5 rows as a sample
    const count = if (rows.len < 5) rows.len else 5;
    for (rows[0..count], 0..) |row, i| {
        std.debug.print("Row {d}: ts={d}, o={d:.2}, h={d:.2}, l={d:.2}, c={d:.2}, v={d}\n", .{ i, row.ts, row.o, row.h, row.l, row.c, row.v });
    }
}
