const std = @import("std");
const testing = std.testing;
const server = @import("server");
const client = @import("client");

test {
    testing.refAllDecls(@This());
}

fn start_server() !void {
    try server.main();
}

test "ping server" {
    const t = try std.Thread.spawn(.{}, start_server, .{});

    t.join();
}
