// File: demo.zig (or examples/demo.zig)
const std = @import("std");
const ohlcv = @import("lib/ohlcv.zig"); // Adjust path based on your project structure

pub fn main() !void {
    // 1. Initialize allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); // Ensure allocator is cleaned up
    const allocator = gpa.allocator();

    // 2. Define parameters
    const from_date = "2023-01-01";
    const to_date = "2023-12-31"; // Fetch data for the year 2023
    const sma_period: u32 = 365; // Calculate 200-day SMA
    const dataset = ohlcv.DataSet.btc_usd; // Use Bitcoin data

    const stdout_writer = std.io.getStdOut().writer();

    try stdout_writer.print("Fetching {s} data from {s} to {s} and calculating {d}-day SMA...\n", .{
        @tagName(dataset), // Get string name of enum
        from_date,
        to_date,
        sma_period,
    });

    // 3. Call the SMA function
    const sma_results = ohlcv.ma.smaForDateRange(
        from_date,
        to_date,
        sma_period,
        dataset,
        allocator,
    ) catch |err| {
        // Handle potential errors from fetching or calculation
        try stdout_writer.print("Error calculating SMA: {any}\n", .{err});
        // Example specific error handling:
        if (err == ohlcv.ma.MAError.InsufficientData) {
            try stdout_writer.print("Not enough data points in the range for the specified period.\n", .{});
        } else if (err == ohlcv.FetchError.HttpError) {
            try stdout_writer.print("Failed to download data. Check internet connection or URL.\n", .{});
        }
        return; // Exit if error occurred
    };

    // IMPORTANT: Free the memory allocated for the results
    defer allocator.free(sma_results);

    // 4. Print the results (e.g., the last 5 SMA values)
    if (sma_results.len == 0) {
        try stdout_writer.print("No SMA results generated (maybe insufficient data).\n", .{});
    } else {
        try stdout_writer.print("\nLast 5 SMA ({d}-day) values:\n", .{sma_period});
        try stdout_writer.print("Timestamp         | SMA Value\n", .{});
        try stdout_writer.print("------------------|-----------\n", .{});

        const start_index = if (sma_results.len > 5) sma_results.len - 5 else 0;
        for (sma_results[start_index..]) |sma_bar| {
            // Format timestamp (assuming UTC YYYY-MM-DD) - requires helper or complex formatting
            // For simplicity, just printing the Unix timestamp here.
            // You would typically convert sma_bar.ts back to YYYY-MM-DD for display.
            try stdout_writer.print("{d:17} | {d:.2}\n", .{
                sma_bar.ts, // Unix timestamp
                sma_bar.c, // SMA value stored in 'c'
            });
        }
    }
}
