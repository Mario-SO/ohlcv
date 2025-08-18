// ╔═══════════════════════════════════════ Fast CSV Parser ═══════════════════════════════════════╗

const std = @import("std");

// ┌──────────────────────────────────── Fast Float Parsing ───────────────────────────────────────┐

/// Fast float parser optimized for CSV data
/// Assumes well-formed input (no NaN, Inf, etc.) for maximum speed
pub fn parseFloat(str: []const u8) !f64 {
    if (str.len == 0) return error.InvalidNumber;
    
    var i: usize = 0;
    var negative = false;
    
    // Handle sign
    if (str[0] == '-') {
        negative = true;
        i = 1;
    } else if (str[0] == '+') {
        i = 1;
    }
    
    if (i >= str.len) return error.InvalidNumber;
    
    // Parse integer part
    var int_part: u64 = 0;
    while (i < str.len and str[i] != '.') : (i += 1) {
        const digit = str[i];
        if (digit < '0' or digit > '9') return error.InvalidNumber;
        
        // Fast multiplication by 10: (x << 3) + (x << 1) = 8x + 2x = 10x
        int_part = (int_part << 3) + (int_part << 1) + (digit - '0');
    }
    
    var result = @as(f64, @floatFromInt(int_part));
    
    // Parse decimal part if present
    if (i < str.len and str[i] == '.') {
        i += 1;
        var decimal_part: u64 = 0;
        var decimal_places: u32 = 0;
        
        // Process up to 15 decimal places for precision
        while (i < str.len and decimal_places < 15) : (i += 1) {
            const digit = str[i];
            if (digit < '0' or digit > '9') break;
            
            decimal_part = (decimal_part << 3) + (decimal_part << 1) + (digit - '0');
            decimal_places += 1;
        }
        
        if (decimal_places > 0) {
            // Use lookup table for common decimal place divisors
            const divisor = DECIMAL_DIVISORS[decimal_places];
            result += @as(f64, @floatFromInt(decimal_part)) / divisor;
        }
    }
    
    return if (negative) -result else result;
}

// Precomputed divisors for decimal places (10^n for n=1..15)
const DECIMAL_DIVISORS = [_]f64{
    0, // unused
    10.0,
    100.0,
    1000.0,
    10000.0,
    100000.0,
    1000000.0,
    10000000.0,
    100000000.0,
    1000000000.0,
    10000000000.0,
    100000000000.0,
    1000000000000.0,
    10000000000000.0,
    100000000000000.0,
    1000000000000000.0,
};

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌──────────────────────────────────── Fast Integer Parsing ─────────────────────────────────────┐

/// Fast integer parser for volume data
pub fn parseInt(str: []const u8) !u64 {
    if (str.len == 0) return error.InvalidNumber;
    
    var result: u64 = 0;
    
    for (str) |c| {
        if (c < '0' or c > '9') return error.InvalidNumber;
        
        // Fast multiplication by 10 and add digit
        result = (result << 3) + (result << 1) + (c - '0');
    }
    
    return result;
}

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌────────────────────────────────── Fast Date Parsing ──────────────────────────────────────────┐

/// Fast date parser for YYYY-MM-DD format (most common in financial data)
pub fn parseDateYYYYMMDD(str: []const u8) !u64 {
    if (str.len < 10) return error.InvalidTimestamp;
    
    // Quick validation and extraction
    if (str[4] != '-' or str[7] != '-') return error.InvalidTimestamp;
    
    // Extract year (4 digits)
    const year = parseDigits4(str[0..4]) catch return error.InvalidTimestamp;
    if (year < 1970) return error.DateBeforeEpoch;
    
    // Extract month (2 digits)
    const month = parseDigits2(str[5..7]) catch return error.InvalidTimestamp;
    if (month < 1 or month > 12) return error.InvalidTimestamp;
    
    // Extract day (2 digits)
    const day = parseDigits2(str[8..10]) catch return error.InvalidTimestamp;
    if (day < 1 or day > 31) return error.InvalidTimestamp;
    
    // Fast conversion to Unix timestamp
    // Using precomputed days since epoch for common years
    const days_since_epoch = daysFromYearMonthDay(year, month, day);
    return days_since_epoch * 86400; // Convert to seconds
}

/// Parse exactly 4 digits
fn parseDigits4(str: []const u8) !u32 {
    if (str.len != 4) return error.InvalidNumber;
    
    var result: u32 = 0;
    for (str) |c| {
        if (c < '0' or c > '9') return error.InvalidNumber;
        result = result * 10 + (c - '0');
    }
    return result;
}

/// Parse exactly 2 digits
fn parseDigits2(str: []const u8) !u32 {
    if (str.len != 2) return error.InvalidNumber;
    
    const d1 = str[0] - '0';
    const d2 = str[1] - '0';
    
    if (d1 > 9 or d2 > 9) return error.InvalidNumber;
    
    return d1 * 10 + d2;
}

/// Calculate days since Unix epoch (1970-01-01)
fn daysFromYearMonthDay(year: u32, month: u32, day: u32) u64 {
    // Days in months (non-leap year)
    const days_in_month = [_]u32{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    
    // Calculate total days
    var total_days: u64 = 0;
    
    // Add days for complete years since 1970
    var y: u32 = 1970;
    while (y < year) : (y += 1) {
        total_days += if (isLeapYear(y)) 366 else 365;
    }
    
    // Add days for complete months in current year
    var m: u32 = 1;
    while (m < month) : (m += 1) {
        total_days += days_in_month[m];
        if (m == 2 and isLeapYear(year)) {
            total_days += 1; // February in leap year
        }
    }
    
    // Add remaining days
    total_days += day - 1; // -1 because we count from day 0
    
    return total_days;
}

/// Check if year is a leap year
fn isLeapYear(year: u32) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌───────────────────────────────── Optimized Line Splitter ─────────────────────────────────────┐

/// Fast CSV line splitter that avoids allocations
pub const LineSplitter = struct {
    line: []const u8,
    pos: usize = 0,
    
    /// Get next field without allocation
    pub fn nextField(self: *LineSplitter) ?[]const u8 {
        if (self.pos >= self.line.len) return null;
        
        const start = self.pos;
        
        // Find next comma or end of line
        while (self.pos < self.line.len and self.line[self.pos] != ',') {
            self.pos += 1;
        }
        
        const field = self.line[start..self.pos];
        
        // Skip comma for next iteration
        if (self.pos < self.line.len) {
            self.pos += 1;
        }
        
        return field;
    }
    
    /// Reset to beginning of line
    pub fn reset(self: *LineSplitter) void {
        self.pos = 0;
    }
};

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ┌─────────────────────────────────── SIMD-Optimized Functions ──────────────────────────────────┐

/// Find comma positions in a buffer using SIMD (when available)
pub fn findCommas(buffer: []const u8, positions: []usize) usize {
    var count: usize = 0;
    
    // TODO: Add SIMD implementation for x86_64 and ARM
    // For now, use scalar implementation
    for (buffer, 0..) |byte, i| {
        if (byte == ',') {
            if (count < positions.len) {
                positions[count] = i;
                count += 1;
            }
        }
    }
    
    return count;
}

/// Count newlines in buffer using SIMD (when available)
pub fn countNewlines(buffer: []const u8) usize {
    var count: usize = 0;
    
    // TODO: Add SIMD implementation
    // For now, use scalar implementation
    for (buffer) |byte| {
        if (byte == '\n') {
            count += 1;
        }
    }
    
    return count;
}

// └───────────────────────────────────────────────────────────────────────────────────────────────┘

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝