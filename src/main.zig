const std = @import("std");
const server = @import("network/server.zig");
const auth = @import("auth/auth.zig");
const core = @import("core/core.zig");
const alloc = std.heap.GeneralPurposeAllocator(.{});

pub fn main() !void {
    server.NetworkInterface.create(h)
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
