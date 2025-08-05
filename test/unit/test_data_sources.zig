// ╔══════════════════════════════════════ Data Source Tests ══════════════════════════════════════╗

const std = @import("std");
const testing = std.testing;
const ohlcv = @import("ohlcv");
const test_helpers = @import("test_helpers");

test "MemoryDataSource provides data correctly" {
    const allocator = testing.allocator;
    
    const csv_data = 
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,105.0,115.0,100.0,112.0,1200000
    ;
    
    var source = try ohlcv.MemoryDataSource.init(allocator, csv_data, false);
    defer source.dataSource().deinit();
    
    const fetched = try source.dataSource().fetch(allocator);
    defer allocator.free(fetched);
    
    try testing.expectEqualStrings(csv_data, fetched);
}

test "FileDataSource reads file correctly" {
    const allocator = testing.allocator;
    
    // Create a temporary test file
    const temp_dir = testing.tmpDir(.{});
    var temp_dir_mut = temp_dir;
    defer temp_dir_mut.cleanup();
    
    const file_path = "test_data.csv";
    const csv_content = 
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
        \\2024-01-02,105.0,115.0,100.0,112.0,1200000
    ;
    
    // Write test data to file
    const file = try temp_dir.dir.createFile(file_path, .{});
    defer file.close();
    try file.writeAll(csv_content);
    
    // Get absolute path
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try temp_dir.dir.realpath(file_path, &path_buffer);
    
    var source = try ohlcv.FileDataSource.init(allocator, abs_path);
    defer source.dataSource().deinit();
    
    const fetched = try source.dataSource().fetch(allocator);
    defer allocator.free(fetched);
    
    try testing.expectEqualStrings(csv_content, fetched);
}

test "DataSource interface works with different implementations" {
    const allocator = testing.allocator;
    
    const csv_data = 
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
    ;
    
    // Test with MemoryDataSource through interface
    var mem_source = try ohlcv.MemoryDataSource.init(allocator, csv_data, false);
    defer mem_source.dataSource().deinit();
    
    const data_source = mem_source.dataSource();
    const fetched = try data_source.fetch(allocator);
    defer allocator.free(fetched);
    
    try testing.expectEqualStrings(csv_data, fetched);
}

test "Multiple fetches from same source work correctly" {
    const allocator = testing.allocator;
    
    const csv_data = 
        \\Date,Open,High,Low,Close,Volume
        \\2024-01-01,100.0,110.0,95.0,105.0,1000000
    ;
    
    var source = try ohlcv.MemoryDataSource.init(allocator, csv_data, false);
    defer source.dataSource().deinit();
    
    // Fetch multiple times
    const fetch1 = try source.dataSource().fetch(allocator);
    defer allocator.free(fetch1);
    
    const fetch2 = try source.dataSource().fetch(allocator);
    defer allocator.free(fetch2);
    
    try testing.expectEqualStrings(csv_data, fetch1);
    try testing.expectEqualStrings(csv_data, fetch2);
}

// ╚════════════════════════════════════════════════════════════════════════════════════════════╝