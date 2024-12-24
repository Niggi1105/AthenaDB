const std = @import("std");
const testing = std.testing;
const hermes = @import("hermes");
const client = @import("client");
const db = @import("db");

test {
    testing.refAllDecls(@This());
}

test "ping-pong" {
    const alloc = testing.allocator;
    var sig = std.Thread.ResetEvent{};
    const t = try std.Thread.spawn(.{}, db.AthenaDB.start, .{ alloc, &sig });
    sig.wait();
    const c1 = try client.Client.connect(alloc, std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));
    try c1.ping();
    const c2 = try client.Client.connect(alloc, std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));
    try c2.shutdown();

    t.join();
}
