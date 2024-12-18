const std = @import("std");
const server = @import("network/server.zig");
const auth = @import("auth/auth.zig");
const core = @import("core/core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var ni = try server.NetworkInterface.create(alloc, 6969);
    try ni.start();
}

test {
    std.testing.refAllDecls(@This());
}
