const std = @import("std");
const Row = @import("../types/row.zig").Row;
const Bar = @import("../types/bar.zig").Bar;
const Allocator = std.mem.Allocator;

pub const EmaOptions = struct {
    period: u32,
};

pub const EMAError = error{
    InsufficientData, // Not enough data points for the period
    InvalidParameters, // e.g., period = 0
    OutOfMemory,
};

pub fn calculateEMA(
    data: []const Row,
    options: EmaOptions,
    alloc: Allocator,
) EMAError![]Bar {
    const period = options.period;

    if (period == 0) return error.InvalidParameters;
    if (data.len < period) return error.InsufficientData;

    var ema_results = std.ArrayList(Bar).init(alloc);
    errdefer ema_results.deinit();

    const alpha: f64 = 2.0 / @as(f64, @floatFromInt(period + 1));
    var ema: f64 = 0;

    for (data[0..period]) |row| {
        ema = row.c * alpha + ema * (1 - alpha);
    }

    try ema_results.append(Bar{
        .ts = data[period - 1].ts,
        .o = 0,
        .h = 0,
        .l = 0,
        .c = ema,
    });

    for (data[period..]) |row| {
        ema = row.c * alpha + ema * (1 - alpha);
        try ema_results.append(Bar{
            .ts = row.ts,
            .o = 0,
            .h = 0,
            .l = 0,
            .c = ema,
        });
    }

    return ema_results.toOwnedSlice();
}
