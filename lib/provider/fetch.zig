const std = @import("std");
const parseAll = @import("../parse/entry.zig").parseAll;
const Row = @import("../core/row.zig").Row;

pub const DataSet = enum { btc_usd, sp500, eth_usd, gold_usd };

/// Fetch a dataset from GitHub and parse it into a slice of `Row`s.
pub fn fetch(ds: DataSet, alloc: std.mem.Allocator) ![]Row {
    const url = switch (ds) {
        .btc_usd => "https://raw.githubusercontent.com/Mario-SO/ohlcv/refs/heads/main/data/btc.csv",
        .sp500 => "https://raw.githubusercontent.com/Mario-SO/ohlcv/refs/heads/main/data/sp500.csv",
        .eth_usd => "https://raw.githubusercontent.com/Mario-SO/ohlcv/refs/heads/main/data/eth.csv",
        .gold_usd => "https://raw.githubusercontent.com/Mario-SO/ohlcv/refs/heads/main/data/gold.csv",
    };

    var client = std.http.Client{ .allocator = alloc };
    defer client.deinit();

    var response_body = std.ArrayList(u8).init(alloc);
    defer response_body.deinit();

    const response = try client.fetch(.{
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &response_body },
    });

    _ = response; // FetchResult is now mainly for status, etc. We don't need it here.

    // const body = try response.reader().readAllAlloc(alloc, 1 << 26); // Old way, erroring
    var stream = std.io.fixedBufferStream(response_body.items);
    return try parseAll(alloc, stream.reader());
}
