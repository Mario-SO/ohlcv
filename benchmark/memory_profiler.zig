// ╔═════════════════════════════════════ Memory Profiler ════════════════════════════════════════╗

const std = @import("std");
const ohlcv = @import("ohlcv");

const MemoryStats = struct {
    allocations: u64 = 0,
    deallocations: u64 = 0,
    bytes_allocated: u64 = 0,
    bytes_freed: u64 = 0,
    peak_memory: u64 = 0,
    current_memory: u64 = 0,

    pub fn logAllocation(self: *MemoryStats, size: usize) void {
        self.allocations += 1;
        self.bytes_allocated += size;
        self.current_memory += size;
        if (self.current_memory > self.peak_memory) {
            self.peak_memory = self.current_memory;
        }
    }

    pub fn logDeallocation(self: *MemoryStats, size: usize) void {
        self.deallocations += 1;
        self.bytes_freed += size;
        self.current_memory -= size;
    }

    pub fn printStats(self: MemoryStats, name: []const u8) void {
        std.debug.print("\n--- Memory Profile: {} ---\n", .{name});
        std.debug.print("Allocations:     {}\n", .{self.allocations});
        std.debug.print("Deallocations:   {}\n", .{self.deallocations});
        std.debug.print("Bytes allocated: {} ({:.2} MB)\n", .{ self.bytes_allocated, @as(f64, @floatFromInt(self.bytes_allocated)) / 1024.0 / 1024.0 });
        std.debug.print("Bytes freed:     {} ({:.2} MB)\n", .{ self.bytes_freed, @as(f64, @floatFromInt(self.bytes_freed)) / 1024.0 / 1024.0 });
        std.debug.print("Peak memory:     {} ({:.2} MB)\n", .{ self.peak_memory, @as(f64, @floatFromInt(self.peak_memory)) / 1024.0 / 1024.0 });
        std.debug.print("Current memory:  {} ({:.2} MB)\n", .{ self.current_memory, @as(f64, @floatFromInt(self.current_memory)) / 1024.0 / 1024.0 });
        std.debug.print("Memory leaked:   {}\n", .{self.allocations != self.deallocations});
        std.debug.print("─────────────────────────────────────\n", .{});
    }
};

const ProfilingAllocator = struct {
    parent: std.mem.Allocator,
    stats: *MemoryStats,

    const Self = @This();

    pub fn init(parent: std.mem.Allocator, stats: *MemoryStats) Self {
        return .{
            .parent = parent,
            .stats = stats,
        };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.parent.rawAlloc(len, log2_ptr_align, ret_addr);
        if (result) |_| {
            self.stats.logAllocation(len);
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        if (self.parent.rawResize(buf, log2_buf_align, new_len, ret_addr)) {
            if (new_len > buf.len) {
                self.stats.logAllocation(new_len - buf.len);
            } else {
                self.stats.logDeallocation(buf.len - new_len);
            }
            return true;
        }
        return false;
    }

    fn free(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.stats.logDeallocation(buf.len);
        self.parent.rawFree(buf, log2_buf_align, ret_addr);
    }
};

fn generateTestData(allocator: std.mem.Allocator, size: usize) ![]ohlcv.OhlcvRow {
    const data = try allocator.alloc(ohlcv.OhlcvRow, size);
    
    for (data, 0..) |*row, i| {
        const base_price = 100.0 + @sin(@as(f64, @floatFromInt(i)) * 0.1) * 20.0;
        row.* = .{
            .u64_timestamp = 1704067200 + i * 86400,
            .f64_open = base_price,
            .f64_high = base_price + 2.0,
            .f64_low = base_price - 2.0,
            .f64_close = base_price + @sin(@as(f64, @floatFromInt(i)) * 0.2),
            .u64_volume = 1000000,
        };
    }
    
    return data;
}

fn profileIndicator(
    allocator: std.mem.Allocator,
    series: ohlcv.TimeSeries,
    name: []const u8,
) !void {
    var stats = MemoryStats{};
    var profiling_alloc = ProfilingAllocator.init(allocator, &stats);
    const prof_allocator = profiling_alloc.allocator();

    // Profile different indicators
    if (std.mem.eql(u8, name, "SMA")) {
        const sma = ohlcv.SmaIndicator{ .u32_period = 20 };
        var result = try sma.calculate(series, prof_allocator);
        result.deinit();
    } else if (std.mem.eql(u8, name, "EMA")) {
        const ema = ohlcv.EmaIndicator{ .u32_period = 20 };
        var result = try ema.calculate(series, prof_allocator);
        result.deinit();
    } else if (std.mem.eql(u8, name, "RSI")) {
        const rsi = ohlcv.RsiIndicator{ .u32_period = 14 };
        var result = try rsi.calculate(series, prof_allocator);
        result.deinit();
    } else if (std.mem.eql(u8, name, "BollingerBands")) {
        const bb = ohlcv.BollingerBandsIndicator{ .u32_period = 20 };
        var result = try bb.calculate(series, prof_allocator);
        result.deinit();
    } else if (std.mem.eql(u8, name, "MACD")) {
        const macd = ohlcv.MacdIndicator{};
        var result = try macd.calculate(series, prof_allocator);
        result.deinit();
    } else if (std.mem.eql(u8, name, "ATR")) {
        const atr = ohlcv.AtrIndicator{ .u32_period = 14 };
        var result = try atr.calculate(series, prof_allocator);
        result.deinit();
    }

    stats.printStats(name);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("╔════════════════════════════════════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                           OHLCV Memory Profiling Results                              ║\n", .{});
    std.debug.print("╚════════════════════════════════════════════════════════════════════════════════════════╝\n", .{});

    const dataset_sizes = [_]usize{ 1000, 10000 };
    const indicators = [_][]const u8{ "SMA", "EMA", "RSI", "BollingerBands", "MACD", "ATR" };

    for (dataset_sizes) |size| {
        std.debug.print("\n🔍 Dataset Size: {} data points\n", .{size});
        std.debug.print("{s}\n", .{"═" ** 50});

        const test_data = try generateTestData(allocator, size);
        defer allocator.free(test_data);
        
        var series = try ohlcv.TimeSeries.fromSlice(allocator, test_data, false);
        defer series.deinit();

        for (indicators) |indicator_name| {
            if (std.mem.eql(u8, indicator_name, "MACD") and size < 50) continue;
            
            try profileIndicator(allocator, series, indicator_name);
        }
    }

    // CSV Parser memory profiling
    std.debug.print("\n🔍 CSV Parser Memory Profile\n", .{});
    std.debug.print("{s}\n", .{"═" ** 50});
    
    var parser_stats = MemoryStats{};
    var profiling_alloc = ProfilingAllocator.init(allocator, &parser_stats);
    const prof_allocator = profiling_alloc.allocator();

    const csv_data =
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,105.0,115.0,100.0,112.0,1200000
        \\2024-01-03,112.0,120.0,108.0,115.0,1100000
    ;

    const parser = ohlcv.CsvParser{ .allocator = prof_allocator };
    var parsed_series = try parser.parse(csv_data);
    parsed_series.deinit();

    parser_stats.printStats("CSV Parser");
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝