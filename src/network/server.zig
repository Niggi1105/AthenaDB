const std = @import("std");
const net = std.net;
const http = std.http;
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

    pub fn create(port: u16) Self {
        const addr = net.Address.initIp4(.{ 127, 0, 0, 1 }, port);
        const server = try addr.listen(.{});
        return Self{ .port = port, .active_conn = atomic.Value(u32).init(0), .server = server };
    }

    pub fn start(self: *Self, alloc: Allocator) void {
        while (true) {
            const conn = try self.server.accept();
            self.active_conn.rmw(AtomicRmwOp.Add, 1, .{});
            Thread.spawn(.{}, handle_conn, .{ conn, alloc });
        }
        return;
    }

    fn handle_conn(conn: net.Server.Connection, alloc: Allocator) void {
        const buf = ArrayList(u8).init(alloc);
        const s = http.Server.init(conn, buf);
        const rq = try s.receiveHead();
        switch (rq.head.method) {
            .GET => {
                std.debug.print("recieved GET request", .{});
            },
            .PUT => {
                std.debug.print("recieved PUT request", .{});
            },
            else => {},
        }
    }
};
