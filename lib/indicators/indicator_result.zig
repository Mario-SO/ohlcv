// ╔══════════════════════════════════════ Indicator Result ══════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Result container for indicator calculations
pub const IndicatorResult = struct {
    const Self = @This();
    
    arr_values: []f64,
    arr_timestamps: []u64,
    allocator: Allocator,
    
    /// Clean up allocated memory
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.arr_values);
        self.allocator.free(self.arr_timestamps);
    }
    
    /// Get the length of the result
    pub fn len(self: Self) usize {
        return self.arr_values.len;
    }
    
    /// Check if empty
    pub fn isEmpty(self: Self) bool {
        return self.arr_values.len == 0;
    }
    
    /// Get value at index
    pub fn getValue(self: Self, index: usize) ?f64 {
        if (index >= self.arr_values.len) return null;
        return self.arr_values[index];
    }
    
    /// Get timestamp at index
    pub fn getTimestamp(self: Self, index: usize) ?u64 {
        if (index >= self.arr_timestamps.len) return null;
        return self.arr_timestamps[index];
    }
    
    /// Get the last value
    pub fn lastValue(self: Self) ?f64 {
        if (self.arr_values.len == 0) return null;
        return self.arr_values[self.arr_values.len - 1];
    }
};

// ╚════════════════════════════════════════════════════════════════════════════════════════════╝