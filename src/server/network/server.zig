const std = @import("std");
const request = @import("hermes").request;
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

    alloc: Allocator,

    const Self = @This();

    pub fn create(alloc: Allocator, port: u16) !Self {
        const addr = net.Address.initIp4(.{ 127, 0, 0, 1 }, port);
        const server = try addr.listen(.{});
        return Self{ .port = port, .active_conn = atomic.Value(u32).init(0), .server = server, .alloc = alloc };
    }

    pub fn start(self: *Self) !void {
        while (true) {
            const conn = try self.server.accept();
            _ = self.active_conn.rmw(AtomicRmwOp.Add, 1, .acq_rel);
            const t = try Thread.spawn(.{}, handle_conn, .{ self.alloc, conn });
            t.detach();
        }
        return;
    }

    fn handle_conn(alloc: Allocator, conn: net.Server.Connection) !void {
        const rq = try request.Request.from_reader(alloc, conn.stream.reader());
        switch (rq.header.request) {
            .PING => {},
            .GET => {},
            .STORE => {},
            .UPDATE => {},
            .DELETE => {},
            .NEWDB => {},
            .DELETEDB => {},
            .LISTDBS => {},
            .CONNECT => {},
            .DISCONNECT => {},
        }
    }
};
