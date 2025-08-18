// ╔══════════════════════════════════════════ Memory Pool ════════════════════════════════════════╗

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Memory pool for efficient allocation of frequently used structures
pub const MemoryPool = struct {
    const Self = @This();
    const POOL_SIZE = 1024 * 1024; // 1MB pools
    const MIN_BLOCK_SIZE = 64; // Minimum allocation size
    
    // ┌───────────────────────────────────────── Structures ──────────────────────────────────────────┐
    
    const Block = struct {
        size: usize,
        used: bool,
        next: ?*Block,
    };
    
    const Pool = struct {
        memory: []u8,
        blocks: ?*Block,
        next: ?*Pool,
        used_bytes: usize,
    };
    
    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
    
    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐
    
    base_allocator: Allocator,
    pools: ?*Pool,
    total_allocated: usize,
    total_used: usize,
    allocations: usize,
    deallocations: usize,
    
    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────────────── Initialization ───────────────────────────────────────────┐
    
    /// Initialize memory pool
    pub fn init(base_allocator: Allocator) Self {
        return .{
            .base_allocator = base_allocator,
            .pools = null,
            .total_allocated = 0,
            .total_used = 0,
            .allocations = 0,
            .deallocations = 0,
        };
    }
    
    /// Clean up all pools
    pub fn deinit(self: *Self) void {
        var pool = self.pools;
        while (pool) |p| {
            const next = p.next;
            self.base_allocator.free(p.memory);
            self.base_allocator.destroy(p);
            pool = next;
        }
        self.pools = null;
    }
    
    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
    
    // ┌───────────────────────────────────── Pool Allocator ──────────────────────────────────────────┐
    
    /// Get allocator interface
    pub fn allocator(self: *Self) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = remap,
            },
        };
    }
    
    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        
        const alignment = @as(usize, 1) << @intFromEnum(ptr_align);
        const aligned_len = std.mem.alignForward(usize, len, alignment);
        
        // Try to find space in existing pools
        var pool = self.pools;
        while (pool) |p| {
            if (p.used_bytes + aligned_len <= p.memory.len) {
                const ptr = p.memory.ptr + p.used_bytes;
                p.used_bytes += aligned_len;
                self.total_used += aligned_len;
                self.allocations += 1;
                return ptr;
            }
            pool = p.next;
        }
        
        // Need new pool
        const new_pool = self.createPool() catch return null;
        const ptr = new_pool.memory.ptr;
        new_pool.used_bytes = aligned_len;
        self.total_used += aligned_len;
        self.allocations += 1;
        
        return ptr;
    }
    
    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        // Memory pools don't support resizing
        return false;
    }
    
    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        _ = buf;
        _ = buf_align;
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.deallocations += 1;
        // Memory pools don't free individual allocations
        // Memory is reclaimed when the pool is reset or destroyed
    }
    
    fn remap(ctx: *anyopaque, old_mem: []u8, buf_align: std.mem.Alignment, new_size: usize, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = old_mem;
        _ = buf_align;
        _ = new_size;
        _ = ret_addr;
        // Memory pools don't support remapping
        return null;
    }
    
    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
    
    // ┌────────────────────────────────────── Pool Management ────────────────────────────────────────┐
    
    /// Create a new pool
    fn createPool(self: *Self) !*Pool {
        const pool = try self.base_allocator.create(Pool);
        errdefer self.base_allocator.destroy(pool);
        
        pool.memory = try self.base_allocator.alloc(u8, POOL_SIZE);
        pool.blocks = null;
        pool.used_bytes = 0;
        pool.next = self.pools;
        
        self.pools = pool;
        self.total_allocated += POOL_SIZE;
        
        return pool;
    }
    
    /// Reset all pools (keep memory allocated but mark as unused)
    pub fn reset(self: *Self) void {
        var pool = self.pools;
        while (pool) |p| {
            p.used_bytes = 0;
            p.blocks = null;
            pool = p.next;
        }
        self.total_used = 0;
    }
    
    /// Get statistics
    pub fn getStats(self: Self) Stats {
        return .{
            .total_allocated = self.total_allocated,
            .total_used = self.total_used,
            .allocations = self.allocations,
            .deallocations = self.deallocations,
            .pool_count = self.countPools(),
            .fragmentation = if (self.total_allocated > 0) 
                @as(f32, @floatFromInt(self.total_allocated - self.total_used)) / @as(f32, @floatFromInt(self.total_allocated))
                else 0,
        };
    }
    
    fn countPools(self: Self) usize {
        var count: usize = 0;
        var pool = self.pools;
        while (pool) |p| {
            count += 1;
            pool = p.next;
        }
        return count;
    }
    
    pub const Stats = struct {
        total_allocated: usize,
        total_used: usize,
        allocations: usize,
        deallocations: usize,
        pool_count: usize,
        fragmentation: f32,
    };
    
    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

/// Arena allocator optimized for indicator calculations
pub const IndicatorArena = struct {
    const Self = @This();
    const ARENA_SIZE = 8 * 1024 * 1024; // 8MB for indicator calculations (handles up to 100K rows)
    
    // ┌───────────────────────────────────────── Attributes ──────────────────────────────────────────┐
    
    base_allocator: Allocator,
    buffer: []u8,
    pos: usize,
    
    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
    
    // ┌──────────────────────────────────── Initialization ───────────────────────────────────────────┐
    
    /// Initialize arena
    pub fn init(base_allocator: Allocator) !Self {
        return .{
            .base_allocator = base_allocator,
            .buffer = try base_allocator.alloc(u8, ARENA_SIZE),
            .pos = 0,
        };
    }
    
    /// Clean up arena
    pub fn deinit(self: Self) void {
        self.base_allocator.free(self.buffer);
    }
    
    /// Reset arena for reuse
    pub fn reset(self: *Self) void {
        self.pos = 0;
    }
    
    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
    
    // ┌───────────────────────────────────── Arena Allocator ─────────────────────────────────────────┐
    
    /// Get allocator interface
    pub fn allocator(self: *Self) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = remap,
            },
        };
    }
    
    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *Self = @ptrCast(@alignCast(ctx));
        
        const alignment = @as(usize, 1) << @intFromEnum(ptr_align);
        const aligned_pos = std.mem.alignForward(usize, self.pos, alignment);
        
        if (aligned_pos + len > self.buffer.len) {
            return null; // Out of space
        }
        
        const ptr = self.buffer.ptr + aligned_pos;
        self.pos = aligned_pos + len;
        return ptr;
    }
    
    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return false; // Arena doesn't support resizing
    }
    
    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = ret_addr;
        // Arena doesn't free individual allocations
    }
    
    fn remap(ctx: *anyopaque, old_mem: []u8, buf_align: std.mem.Alignment, new_size: usize, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = old_mem;
        _ = buf_align;
        _ = new_size;
        _ = ret_addr;
        // Arena doesn't support remapping
        return null;
    }
    
    // └───────────────────────────────────────────────────────────────────────────────────────────────┘
};

// ╚═══════════════════════════════════════════════════════════════════════════════════════════════╝