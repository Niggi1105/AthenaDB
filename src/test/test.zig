const std = @import("std");
const testing = std.testing;
const hermes = @import("hermes");
const client = @import("client");
const server = @import("server");

test {
    testing.refAllDecls(@This());
}

test "ping-pong" {
    const t = try std.Thread.spawn(.{}, server.main, .{});
    t.detach();
    const c = client.Client.
}
