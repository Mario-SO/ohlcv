// ╔══════════════════════════════════════ Fetch (Provider) ══════════════════════════════════════╗

const std = @import("std");
const Row = @import("../types/row.zig").Row;
const ParseError = @import("../types/errors.zig").ParseError;
const FetchError = @import("../types/errors.zig").FetchError;

// ┌──────────────────────────── DataSet ────────────────────────────┐

/// Available remote data sets for `fetch`.
pub const DataSet = enum { btc_usd, sp500, eth_usd, gold_usd };

// └──────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── fetch() ────────────────────────────┐

/// Fetches remote OHLCV CSV and parses into `Row`s.
pub fn fetch(ds: DataSet, alloc: std.mem.Allocator) FetchError![]Row {
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

    const response = client.fetch(.{
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &response_body },
    }) catch return FetchError.HttpError;

    _ = response;

    var stream = std.io.fixedBufferStream(response_body.items);
    return @import("../parser/parser.zig").parseCsvFast(alloc, stream.reader()) catch |e| return e;
}

// └──────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════╝
