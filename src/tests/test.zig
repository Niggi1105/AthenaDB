const std = @import("std");
const testing = std.testing;
const server = @import("server");
const client = @import("client");
const hermes = @import("hermes");

test {
    testing.refAllDecls(@This());
}

fn start_server() !void {
    try server.main();
}

test "ping server" {
    const alloc = testing.allocator;
    const t = try std.Thread.spawn(.{}, start_server, .{});

    std.log.info("server started...", .{});

    const c = try client.Client.connect(alloc);
    std.log.info("connected to server...", .{});

    const resp = try c.ping();
    std.log.info("got response", .{});

    const s = try c.shutdown();

    try testing.expect(s.header.status == .OK);

    try testing.expectEqualDeep(hermes.response.ResponseHeader{ .status = .OK, .version = resp.header.version, .len = 4 }, resp.header);
    try testing.expectEqualSlices(u8, "PONG", resp.data);
    t.join();
}
