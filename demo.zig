const std = @import("std");
const print = std.debug.print;

const ohlcv = @import("ohlcv");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const alloc = gpa.allocator();

    // Fetch S&P 500 data
    const rows = try ohlcv.fetch(.sp500, alloc);
    defer alloc.free(rows); // Remember to free the allocated memory

    std.debug.print("Fetched {d} rows of data.\n", .{rows.len});

    // Process the 'rows' slice...
    for (rows) |row| {
        // Access row data: row.ts, row.o, row.h, row.l, row.c, row.v
        print("Row: {d:.2}\n", .{row.ts});
        print("Open: {d:.2}\n", .{row.o});
        print("High: {d:.2}\n", .{row.h});
        print("Low: {d:.2}\n", .{row.l});
        print("Close: {d:.2}\n", .{row.c});
        print("Volume: {d}\n", .{row.v});
    }
}
