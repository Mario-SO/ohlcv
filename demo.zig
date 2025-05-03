const std = @import("std");
const ohlcv = @import("lib/ohlcv.zig");

// Function to run the SMA calculation and handle errors
fn runSmaCalculation(
    allocator: std.mem.Allocator,
    writer: anytype, // Use anytype for flexibility (e.g., stdout, file writer)
    from_date: []const u8,
    to_date: []const u8,
    options: ohlcv.indicators.SmaOptions,
    dataset: ohlcv.DataSet,
) !?[]ohlcv.Bar { // Returns optional slice, or an error if printing fails
    try writer.print("\nFetching {s} data from {s} to {s} and calculating {d}-day SMA...\n", .{
        @tagName(dataset),
        from_date,
        to_date,
        options.period,
    });

    const results = ohlcv.indicators.calculateSMAForRange(
        from_date,
        to_date,
        options,
        dataset,
        allocator,
    ) catch |err| {
        // Handle errors directly within this function
        try writer.print("Error calculating SMA: {any}\n", .{err});
        if (err == ohlcv.indicators.SMAError.InsufficientData) {
            try writer.print("Not enough data points in the range for the specified period.\n", .{});
        } else if (err == ohlcv.FetchError.HttpError) {
            try writer.print("Failed to download data. Check internet connection or URL.\n", .{});
        } else if (err == ohlcv.indicators.SMAError.InvalidParameters) {
            try writer.print("Invalid parameters for SMA (e.g., period=0).\n", .{});
        }
        // Return null to indicate an error occurred and was handled
        return null;
    };

    // Return the successfully calculated results
    return results;
}

// Function to print the SMA results table
fn printSmaResultsTable(
    writer: anytype,
    results: []const ohlcv.Bar,
    options: ohlcv.indicators.SmaOptions,
) !void {
    if (results.len == 0) {
        try writer.print("No SMA results generated (check period vs date range).\n", .{});
    } else {
        try writer.print("\nLast 5 SMA ({d}-day) values:\n", .{options.period});
        try writer.print("Timestamp         | SMA Value\n", .{});
        try writer.print("------------------|-----------\n", .{});

        const start_index = if (results.len > 5) results.len - 5 else 0;
        for (results[start_index..]) |sma_bar| {
            try writer.print("{d:17} | {d:.2}\n", .{
                sma_bar.ts,
                sma_bar.c, // SMA value stored in 'c'
            });
        }
    }
}

// Function to run the EMA calculation and handle errors
fn runEmaCalculation(
    allocator: std.mem.Allocator,
    writer: anytype,
    from_date: []const u8,
    to_date: []const u8,
    options: ohlcv.indicators.EmaOptions, // Use EmaOptions
    dataset: ohlcv.DataSet,
) !?[]ohlcv.Bar {
    try writer.print("\nFetching {s} data from {s} to {s} and calculating {d}-period EMA...\n", .{ // Added newline & EMA text
        @tagName(dataset),
        from_date,
        to_date,
        options.period,
    });

    // Assume calculateEMAForRange exists and follows a similar pattern
    const results = ohlcv.indicators.calculateEMAForRange(
        from_date,
        to_date,
        options, // Pass EmaOptions
        dataset,
        allocator,
    ) catch |err| {
        try writer.print("Error calculating EMA: {any}\n", .{err});
        // Adjust error handling for potential EMA-specific errors
        if (err == ohlcv.indicators.EMAError.InsufficientData) { // Assume EMAError exists
            try writer.print("Not enough data points in the range for the specified period.\n", .{});
        } else if (err == ohlcv.FetchError.HttpError) {
            try writer.print("Failed to download data. Check internet connection or URL.\n", .{});
        } else if (err == ohlcv.indicators.EMAError.InvalidParameters) { // Assume EMAError exists
            try writer.print("Invalid parameters for EMA (e.g., period=0).\n", .{});
        }
        return null;
    };

    return results;
}

// Function to print the EMA results table
fn printEmaResultsTable(
    writer: anytype,
    results: []const ohlcv.Bar,
    options: ohlcv.indicators.EmaOptions, // Use EmaOptions
) !void {
    if (results.len == 0) {
        try writer.print("No EMA results generated (check period vs date range).\n", .{});
    } else {
        try writer.print("\nLast 5 EMA ({d}-period) values:\n", .{options.period}); // Changed SMA to EMA
        try writer.print("Timestamp         | EMA Value\n", .{}); // Changed SMA to EMA
        try writer.print("------------------|-----------\n", .{});

        const start_index = if (results.len > 5) results.len - 5 else 0;
        for (results[start_index..]) |ema_bar| { // Renamed loop variable
            try writer.print("{d:17} | {d:.2}\n", .{
                ema_bar.ts,
                ema_bar.c, // Assuming EMA value is also stored in 'c'
            });
        }
    }
}

fn runRsiCalculation(
    allocator: std.mem.Allocator,
    writer: anytype,
    from_date: []const u8,
    to_date: []const u8,
    options: ohlcv.indicators.RsiOptions,
    dataset: ohlcv.DataSet,
) !?[]ohlcv.Bar {
    try writer.print("\nFetching {s} data from {s} to {s} and calculating {d}-period RSI...\n", .{
        @tagName(dataset),
        from_date,
        to_date,
        options.period,
    });

    const results = ohlcv.indicators.calculateRSIForRange(
        from_date,
        to_date,
        options,
        dataset,
        allocator,
    ) catch |err| {
        try writer.print("Error calculating RSI: {any}\n", .{err});
        if (err == ohlcv.indicators.RSIError.InsufficientData) {
            try writer.print("Not enough data points in the range for the specified period.\n", .{});
        } else if (err == ohlcv.FetchError.HttpError) {
            try writer.print("Failed to download data. Check internet connection or URL.\n", .{});
        } else if (err == ohlcv.indicators.RSIError.InvalidParameters) {
            try writer.print("Invalid parameters for RSI (e.g., period=0).\n", .{});
        }
        return null;
    };

    return results;
}

fn printRsiResultsTable(
    writer: anytype,
    results: []const ohlcv.Bar,
    options: ohlcv.indicators.RsiOptions,
) !void {
    if (results.len == 0) {
        try writer.print("No RSI results generated (check period vs date range).\n", .{});
    } else {
        try writer.print("\nLast 5 RSI ({d}-period) values:\n", .{options.period});
        try writer.print("Timestamp         | RSI Value\n", .{});
        try writer.print("------------------|-----------\n", .{});

        const start_index = if (results.len > 5) results.len - 5 else 0;
        for (results[start_index..]) |rsi_bar| {
            try writer.print("{d:17} | {d:.2}\n", .{
                rsi_bar.ts,
                rsi_bar.c,
            });
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Configuration
    const from_date = "2023-01-01";
    const to_date = "2023-12-31";
    const sma_options = ohlcv.indicators.SmaOptions{ .period = 200 }; // Example: 200-day SMA
    const dataset = ohlcv.DataSet.btc_usd;

    const stdout_writer = std.io.getStdOut().writer();

    // Run calculation and handle potential printing errors from runSmaCalculation
    if (try runSmaCalculation(allocator, stdout_writer, from_date, to_date, sma_options, dataset)) |sma_results| {
        // If calculation succeeded (returned non-null), defer freeing and print results
        defer allocator.free(sma_results);
        try printSmaResultsTable(stdout_writer, sma_results, sma_options);
    } else {
        // If runSmaCalculation returned null, it means an error occurred
        // and was already printed. We can just exit cleanly or add more logging here.
        // std.log.info("SMA calculation failed, see error message above.", .{});
    }

    // --- Run EMA ---
    // Configure EMA options (example: 12-period EMA)
    const ema_options = ohlcv.indicators.EmaOptions{ .period = 12 }; // REVERTED PATH
    if (try runEmaCalculation(allocator, stdout_writer, from_date, to_date, ema_options, dataset)) |ema_results| {
        defer allocator.free(ema_results); // Free EMA results memory
        try printEmaResultsTable(stdout_writer, ema_results, ema_options); // Print EMA table
    } else {
        // Error already printed in runEmaCalculation
    }

    // --- Run RSI ---
    const rsi_options = ohlcv.indicators.RsiOptions{ .period = 14 }; // Default RSI period
    if (try runRsiCalculation(allocator, stdout_writer, from_date, to_date, rsi_options, dataset)) |rsi_results| {
        defer allocator.free(rsi_results); // Free RSI results memory
        try printRsiResultsTable(stdout_writer, rsi_results, rsi_options); // Print RSI table
    } else {
        // Error already printed in runRsiCalculation
    }
}
