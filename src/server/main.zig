const std = @import("std");
const server = @import("network/server.zig");
const auth = @import("auth/auth.zig");
const core = @import("core/core.zig");

pub fn main() !void {
    var ni = try server.NetworkInterface.create(6969);
    try ni.start();
}

test {
    std.testing.refAllDecls(@This());
}
