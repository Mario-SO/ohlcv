// ╔══════════════════════════════════════ Integration Tests ══════════════════════════════════════╗

const std = @import("std");
const testing = std.testing;
const ohlcv = @import("ohlcv");

test "Full workflow: fetch, parse, filter, calculate indicators" {
    const allocator = testing.allocator;
    
    // Create sample CSV data
    const csv_data = 
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,105.0,115.0,100.0,112.0,1200000
        \\2024-01-03,112.0,120.0,108.0,115.0,1100000
        \\2024-01-04,115.0,118.0,110.0,113.0,900000
        \\2024-01-05,113.0,117.0,111.0,116.0,1050000
        \\2024-01-06,116.0,125.0,114.0,124.0,1300000
        \\2024-01-07,124.0,128.0,120.0,122.0,1150000
        \\2024-01-08,122.0,126.0,118.0,125.0,1250000
        \\2024-01-09,125.0,130.0,123.0,128.0,1400000
        \\2024-01-10,128.0,132.0,125.0,130.0,1500000
    ;
    
    // Step 1: Create data source
    var memory_source = try ohlcv.MemoryDataSource.init(allocator, csv_data, false);
    defer memory_source.dataSource().deinit();
    
    // Step 2: Fetch data
    const data = try memory_source.dataSource().fetch(allocator);
    defer allocator.free(data);
    
    // Step 3: Parse CSV
    const parser = ohlcv.CsvParser{ .allocator = allocator };
    var series = try parser.parse(data);
    defer series.deinit();
    
    try testing.expectEqual(@as(usize, 10), series.len());
    
    // Step 4: Filter by volume
    const high_volume = try series.filter(struct {
        fn predicate(row: ohlcv.OhlcvRow) bool {
            return row.u64_volume >= 1_200_000;
        }
    }.predicate);
    defer high_volume.deinit();
    
    try testing.expectEqual(@as(usize, 5), high_volume.len());
    
    // Step 5: Calculate indicators
    const sma = ohlcv.SmaIndicator{ .u32_period = 3 };
    var sma_result = try sma.calculate(series, allocator);
    defer sma_result.deinit();
    
    const ema = ohlcv.EmaIndicator{ .u32_period = 3 };
    var ema_result = try ema.calculate(series, allocator);
    defer ema_result.deinit();
    
    const rsi = ohlcv.RsiIndicator{ .u32_period = 5 };
    var rsi_result = try rsi.calculate(series, allocator);
    defer rsi_result.deinit();
    
    // Verify results exist
    try testing.expect(sma_result.len() > 0);
    try testing.expect(ema_result.len() > 0);
    try testing.expect(rsi_result.len() > 0);
}

test "Multiple data sources produce same results" {
    const allocator = testing.allocator;
    
    const csv_data = 
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,105.0,115.0,100.0,112.0,1200000
    ;
    
    // Test with memory source
    var mem_source = try ohlcv.MemoryDataSource.init(allocator, csv_data, false);
    defer mem_source.dataSource().deinit();
    
    const mem_data = try mem_source.dataSource().fetch(allocator);
    defer allocator.free(mem_data);
    
    // Test with file source
    const temp_dir = testing.tmpDir(.{});
    var temp_dir_mut = temp_dir;
    defer temp_dir_mut.cleanup();
    
    const file_path = "test.csv";
    const file = try temp_dir.dir.createFile(file_path, .{});
    defer file.close();
    try file.writeAll(csv_data);
    
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try temp_dir.dir.realpath(file_path, &path_buffer);
    
    var file_source = try ohlcv.FileDataSource.init(allocator, abs_path);
    defer file_source.dataSource().deinit();
    
    const file_data = try file_source.dataSource().fetch(allocator);
    defer allocator.free(file_data);
    
    // Both should produce same data
    try testing.expectEqualStrings(mem_data, file_data);
}

test "Time series operations preserve data integrity" {
    const allocator = testing.allocator;
    
    // Create 30 days of data
    var rows: [30]ohlcv.OhlcvRow = undefined;
    const base_ts: u64 = 1704067200; // 2024-01-01
    const day: u64 = 86400;
    
    for (&rows, 0..) |*row, i| {
        const f_index = @as(f64, @floatFromInt(i));
        row.* = .{
            .u64_timestamp = base_ts + i * day,
            .f64_open = 100.0 + f_index,
            .f64_high = 110.0 + f_index,
            .f64_low = 90.0 + f_index,
            .f64_close = 105.0 + f_index,
            .u64_volume = 1000000 + i * 10000,
        };
    }
    
    const rows_slice = try allocator.dupe(ohlcv.OhlcvRow, &rows);
    defer allocator.free(rows_slice);
    
    var series = try ohlcv.TimeSeries.fromSlice(allocator, rows_slice, false);
    defer series.deinit();
    
    // Test slicing
    const week1 = try series.sliceByTime(base_ts, base_ts + 6 * day);
    const week2 = try series.sliceByTime(base_ts + 7 * day, base_ts + 13 * day);
    
    try testing.expectEqual(@as(usize, 7), week1.len());
    try testing.expectEqual(@as(usize, 7), week2.len());
    
    // Verify no overlap
    try testing.expect(week1.arr_rows[week1.len() - 1].u64_timestamp < week2.arr_rows[0].u64_timestamp);
}

// ╚════════════════════════════════════════════════════════════════════════════════════════════╝