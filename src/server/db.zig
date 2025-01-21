const std = @import("std");
const net = @import("net.zig");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;
const handle_req = AthenaCore.handle_req;
const Request = @import("hermes").request.Request;
const core = @import("core.zig");
pub const AthenaCore = core.AthenaCore;

pub const AthenaDB = struct {
    pub fn start(alloc: Allocator, mark: *std.Thread.ResetEvent) !void {
        var dir = try std.fs.cwd().makeOpenPath("./db_files/", .{});
        std.log.info("opened db directory...", .{});
        defer dir.close();
        var acore = AthenaCore{ .alloc = alloc, .mutex = Thread.Mutex{}, .base_dir = dir };
        std.log.info("started db core...", .{});

        var ni = try net.NetworkInterface.start(alloc, std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));

        var pool: Thread.Pool = undefined;
        try Thread.Pool.init(&pool, .{ .allocator = alloc });
        defer pool.deinit();

        mark.set();

        while (ni.next_conn()) |conn| {
            std.log.info("got new connection from: {}", .{conn.address});
            const rq = try Request.from_reader(alloc, conn.stream.reader());
            defer rq.deinit();
            if (rq.header.method == .Shutdown) {
                return;
            } else {
                try pool.spawn(handle_req, .{ conn, rq, &acore });
            }
        } else |err| {
            std.log.err("can't accept new connection: {}", .{err});
            return err;
        }
    }
};

test {
    std.testing.refAllDecls(@This());
}
