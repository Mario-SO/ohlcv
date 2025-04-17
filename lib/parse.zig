// ╔══════════════════════════════════════ Parsing API ══════════════════════════════════════╗

// ┌──────────────────────────── Imports ────────────────────────────┐

const std = @import("std");
const Row = @import("types.zig").Row;
const ParseError = @import("errors.zig").ParseError;

// └─────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── parseCsv ────────────────────────────┐

/// Parses CSV data from a generic reader into a slice of `Row` using the default parser.
pub fn parseCsv(allocator: std.mem.Allocator, reader: anytype) ![]Row {
    return @import("parse/entry.zig").parseCsv(allocator, reader);
}

// └──────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── parseCsvFast ────────────────────────────┐

/// Parses CSV data from a generic reader into a slice of `Row` using the fast state-machine parser.
pub fn parseCsvFast(allocator: std.mem.Allocator, reader: anytype) ![]Row {
    return @import("parse/entry.zig").parseCsvFast(allocator, reader);
}

// └──────────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── parseFileCsv ────────────────────────────┐

/// Parses CSV data from a file at the given path into a slice of `Row`.
pub fn parseFileCsv(allocator: std.mem.Allocator, filePath: []const u8) ![]Row {
    const file = try std.fs.cwd().openFile(filePath, .{ .read = true });
    defer file.close();
    return parseCsv(allocator, file.reader());
}

// └──────────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────── parseStringCsv ────────────────────────────┐

/// Parses CSV data from an in-memory string into a slice of `Row`.
pub fn parseStringCsv(allocator: std.mem.Allocator, data: []const u8) ![]Row {
    var stream = std.io.fixedBufferStream(data);
    return parseCsv(allocator, stream.reader());
}

// └────────────────────────────────────────────────────────────────────────┘

// ╚══════════════════════════════════════════════════════════════════════════════════╝
