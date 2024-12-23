const std = @import("std");
const net = @import("net.zig");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;
pub const AthenaCore = @import("core.zig").AthenaCore;
const handle_req = AthenaCore.handle_req;

pub const AthenaDB = struct {
    const Self = @This();

    pub fn start(alloc: Allocator, core: *AthenaCore) !void {
        _ = core;
        var ni = try net.NetworkInterface.start(alloc, std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));
        var pool: Thread.Pool = undefined;
        try Thread.Pool.init(&pool, .{ .allocator = alloc });
        while (ni.next_conn()) |conn| {
            std.log.info("got new connection from: {}", .{conn.address});
            try pool.spawn(handle_req, .{conn});
        } else |err| {
            std.log.err("can't accept new connection: {}", .{err});
        }
    }
};
