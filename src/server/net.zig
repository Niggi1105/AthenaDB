const std = @import("std");
const hermes = @import("hermes");
const net = std.net;
const Allocator = std.mem.Allocator;
const request = hermes.request;
const Request = request.Request;
const response = hermes.response;
const Response = response.Response;

pub const NetworkInterface = struct {
    addr: net.Address,
    server: net.Server,

    const Self = @This();

    pub fn start(addr: net.Address) !Self {
        std.log.info("starting network interface...", .{});

        const server = try addr.listen(.{});
        return Self{ .addr = addr, .server = server };
    }

    ///blocks until next incomming request
    pub fn next_conn(self: *Self) !std.net.Server.Connection {
        std.log.info("start listening for connections...", .{});

        return self.server.accept();
    }

    pub fn deinit(self: Self) void {
        self.pool.deinit();
    }
};
