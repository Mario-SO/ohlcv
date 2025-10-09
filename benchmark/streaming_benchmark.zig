// ╔════════════════════════════════════ Streaming Benchmark ══════════════════════════════════════╗

const std = @import("std");
const ohlcv = @import("ohlcv");
const print = std.debug.print;
const ArrayList = std.array_list.Managed;

fn generateCsvData(allocator: std.mem.Allocator, rows: usize) ![]u8 {
    var buffer = ArrayList(u8).init(allocator);
    errdefer buffer.deinit();

    // Add header
    try buffer.appendSlice("Date,Open,High,Low,Close,Volume\n");

    // Generate rows
    var price: f64 = 100.0;
    for (0..rows) |i| {
        price += (@sin(@as(f64, @floatFromInt(i)) * 0.1) * 2.0);
        const date = 1704067200 + i * 86400; // Starting from 2024-01-01

        // Format date as YYYY-MM-DD
        const seconds_since_epoch = @as(i64, @intCast(date));
        const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(seconds_since_epoch) };
        const epoch_day = epoch_seconds.getEpochDay();
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();

        try buffer.writer().print("{d:0>4}-{d:0>2}-{d:0>2},{d:.2},{d:.2},{d:.2},{d:.2},{d}\n", .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            price,
            price + 2.0,
            price - 2.0,
            price + @sin(@as(f64, @floatFromInt(i)) * 0.2),
            1000000 + i * 100,
        });
    }

    return buffer.toOwnedSlice();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    print("\n╔════════════════════════════════════════════════════════════════╗\n", .{});
    print("║              Streaming vs Non-Streaming Benchmark              ║\n", .{});
    print("╚════════════════════════════════════════════════════════════════╝\n\n", .{});

    const test_sizes = [_]usize{ 1000, 10000, 50000 };

    for (test_sizes) |size| {
        print("📊 Dataset: {} rows\n", .{size});
        print("{s}\n", .{"─" ** 60});

        // Generate test CSV data
        const csv_data = try generateCsvData(allocator, size);
        defer allocator.free(csv_data);

        const csv_size_kb = @as(f64, @floatFromInt(csv_data.len)) / 1024.0;
        print("CSV Size: {d:.2} KB\n\n", .{csv_size_kb});

        // Benchmark standard parser
        {
            const start_time = std.time.nanoTimestamp();

            const parser = ohlcv.CsvParser{ .allocator = allocator };
            var series = try parser.parse(csv_data);
            defer series.deinit();

            const end_time = std.time.nanoTimestamp();
            const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

            const memory_used = @as(f64, @floatFromInt(series.len() * @sizeOf(ohlcv.OhlcvRow))) / 1024.0;

            print("Standard Parser:\n", .{});
            print("  ⏱️  Time:          {d:>8.3} ms\n", .{duration_ms});
            print("  💾 Memory (rows):  {d:>8.2} KB\n", .{memory_used});
            print("  📈 Rows parsed:    {}\n", .{series.len()});
            print("  ⚡ Throughput:     {d:>8.0} rows/ms\n\n", .{@as(f64, @floatFromInt(series.len())) / duration_ms});
        }

        // Benchmark streaming parser
        {
            const start_time = std.time.nanoTimestamp();

            var parser = try ohlcv.StreamingCsvParser.init(allocator);
            defer parser.deinit();

            var series = try parser.parse(csv_data);
            defer series.deinit();

            const end_time = std.time.nanoTimestamp();
            const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;

            const memory_used = @as(f64, @floatFromInt(series.len() * @sizeOf(ohlcv.OhlcvRow))) / 1024.0;
            const buffer_memory = 4.0; // 4KB buffer

            print("Streaming Parser:\n", .{});
            print("  ⏱️  Time:          {d:>8.3} ms\n", .{duration_ms});
            print("  💾 Memory (rows):  {d:>8.2} KB\n", .{memory_used});
            print("  🔄 Buffer size:    {d:>8.2} KB\n", .{buffer_memory});
            print("  📈 Rows parsed:    {}\n", .{series.len()});
            print("  ⚡ Throughput:     {d:>8.0} rows/ms\n\n", .{@as(f64, @floatFromInt(series.len())) / duration_ms});
        }

        // Benchmark streaming with row-by-row processing
        {
            const start_time = std.time.nanoTimestamp();

            var parser = try ohlcv.StreamingCsvParser.init(allocator);
            defer parser.deinit();

            var row_count: usize = 0;
            var sum_close: f64 = 0;

            // Feed data in chunks
            const chunk_size = 4096;
            var offset: usize = 0;
            while (offset < csv_data.len) {
                const end = @min(offset + chunk_size, csv_data.len);
                try parser.feedData(csv_data[offset..end]);
                offset = end;

                // Process rows as they become available
                while (try parser.nextRow()) |row| {
                    row_count += 1;
                    sum_close += row.f64_close;
                }
            }

            // Signal end and process remaining
            parser.endStream();
            while (try parser.nextRow()) |row| {
                row_count += 1;
                sum_close += row.f64_close;
            }

            const end_time = std.time.nanoTimestamp();
            const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
            const avg_close = sum_close / @as(f64, @floatFromInt(row_count));

            print("Streaming (Row-by-Row):\n", .{});
            print("  ⏱️  Time:          {d:>8.3} ms\n", .{duration_ms});
            print("  💾 Peak memory:    ~4.25 KB (buffer + line)\n", .{});
            print("  📈 Rows processed: {}\n", .{row_count});
            print("  📊 Avg close:      {d:.2}\n", .{avg_close});
            print("  ⚡ Throughput:     {d:>8.0} rows/ms\n", .{@as(f64, @floatFromInt(row_count)) / duration_ms});
        }

        print("\n" ++ "=" ** 60 ++ "\n\n", .{});
    }

    print("✅ Streaming benchmark completed!\n", .{});
}

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝
