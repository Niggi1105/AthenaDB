const std = @import("std");
const net = std.net;
const Thread = std.Thread;
const atomic = std.atomic;
const AtomicRmwOp = std.builtin.AtomicRmwOp;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const NetworkInterface = struct {
    server: net.Server,
    active_conn: atomic.Value(u32),
    port: u16,

    const Self = @This();

    pub fn create(port: u16) !Self {
        const addr = net.Address.initIp4(.{ 127, 0, 0, 1 }, port);
        const server = try addr.listen(.{});
        return Self{ .port = port, .active_conn = atomic.Value(u32).init(0), .server = server };
    }

    pub fn start(self: *Self) !void {
        while (true) {
            const conn = try self.server.accept();
            _ = self.active_conn.rmw(AtomicRmwOp.Add, 1, .acq_rel);
            const t = try Thread.spawn(.{}, handle_conn, .{conn});
            t.detach();
        }
        return;
    }

    // uses the following protocol:
    // packet: header | payload
    // -----------------------------------------------
    // 4 bytes: "HEAD"
    // 4 bytes: len - 4
    // 4 bytes: checksum
    // 3 bytes: flags
    // 3 bytes: version
    // 1 byte: status
    // 1 byte: Request type
    // 4 bytes: "BODY"
    // len - 24 byte payload: encoded data
    fn handle_conn(conn: net.Server.Connection) !void {}
};
