const std = @import("std");
const testing = std.testing;
const hermes = @import("hermes");
const client = @import("client");
const db = @import("db");

test {
    const alloc = std.testing.allocator;
    var start = std.Thread.ResetEvent{};
    var stop = std.Thread.ResetEvent{};

    const t = try std.Thread.spawn(.{}, db.AthenaDB.test_start, .{ alloc, &start, &stop });
    t.detach();

    start.wait();

    stop.set();

    const c = try client.Client.connect(alloc, std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));
    const data = "Hello World!!";

    var slice = std.mem.toBytes(data.*);
    const rsp = try c.put(&slice);
    defer rsp.deinit();
    try std.testing.expect(rsp.header.code == .Ok);

    const rsp2 = try c.get(rsp.header.key);
    defer rsp2.deinit();

    const rsp3 = try c.delete(rsp.header.key);
    defer rsp3.deinit();
    try std.testing.expect(rsp2.header.code == .Ok);

    try c.disconnect();

    try std.testing.expect(rsp2.header.code == .Ok);
    try std.testing.expectEqualSlices(u8, &slice, rsp2.body);
    testing.refAllDecls(@This());
}
