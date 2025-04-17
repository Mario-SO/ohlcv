const std = @import("std");
const print = std.debug.print;
const Row = @import("../core/row.zig").Row;
const state = @import("state.zig");

pub fn parseAll(alloc: std.mem.Allocator, reader: anytype) ![]Row {
    const in = reader;

    var line_count: usize = 0;
    while (true) {
        const line = in.readUntilDelimiterOrEofAlloc(alloc, '\n', 1 << 12) catch |err| {
            if (err == error.EndOfStream) {
                break; // Found end of stream
            } else {
                return err; // Propagate other errors
            }
        };
        // Successful read
        if (line) |actual_line| {
            alloc.free(actual_line); // Free the allocated line only if it's not null
        } else {
            // Handle the null case if necessary, maybe break or continue?
            // If null signifies EOF without error, we should probably break.
            break;
        }
        line_count += 1;
    }

    return &[_]Row{};
}
