const std = @import("std");
const testing = std.testing;
const hermes = @import("hermes");
const client = @import("client");
const db = @import("db");
const AthenaCore = db.AthenaCore;

test {
    testing.refAllDecls(@This());
}

test "ping-pong" {
    const alloc = testing.allocator;
    var core = AthenaCore{};
    const t = try std.Thread.spawn(.{}, db.AthenaDB.start, .{ alloc, &core });
    t.detach();
    const c = try client.Client.connect(alloc, std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));
    _ = try c.ping();
}
