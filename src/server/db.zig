const std = @import("std");
const net = @import("net.zig");
const core = @import("core.zig");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;
const Request = @import("hermes").request.Request;

pub const AthenaDB = struct {
    pub fn start(alloc: Allocator) !void {
        var dir = try std.fs.cwd().makeOpenPath("./db_files/", .{});
        defer dir.close();

        std.log.info("opened db directory...", .{});

        var acore = core.AthenaCore{ .alloc = alloc, .mutex = Thread.Mutex{}, .base_dir = dir };

        var net_interface = try net.NetworkInterface.start(std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));

        var pool: Thread.Pool = undefined;
        try Thread.Pool.init(&pool, .{ .allocator = alloc });
        defer pool.deinit();

        while (net_interface.next_conn()) |conn| {
            std.log.info("got new connection from: {}", .{conn.address});

            try pool.spawn(core.AthenaCore.handle_conn, .{
                &acore,
                conn,
            });
        } else |err| {
            std.log.err("can't accept new connection: {}", .{err});
            return err;
        }
    }
    ///should only be used in tests, this is not supposed to run in any production environment
    pub fn test_start(alloc: Allocator, ready: *std.Thread.ResetEvent, stop: *std.Thread.ResetEvent) !void {
        var dir = try std.fs.cwd().makeOpenPath("./db_files/", .{});
        defer dir.close();

        std.log.info("opened db directory...", .{});

        var acore = core.AthenaCore{ .alloc = alloc, .mutex = Thread.Mutex{}, .base_dir = dir };

        var net_interface = try net.NetworkInterface.start(std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));

        var pool: Thread.Pool = undefined;
        try Thread.Pool.init(&pool, .{ .allocator = alloc });
        defer pool.deinit();

        ready.set();
        if (stop.isSet()) {
            return;
        }
        while (net_interface.next_conn()) |conn| {
            std.log.info("got new connection from: {}", .{conn.address});

            try pool.spawn(core.AthenaCore.handle_conn, .{
                &acore,
                conn,
            });
        } else |err| {
            std.log.err("can't accept new connection: {}", .{err});
            return err;
        }
    }
};

test {
    std.testing.refAllDecls(@This());
}
