const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const hermes = @import("hermes");
const request = hermes.request;
const response = hermes.response;

pub const Client = struct {
    stream: net.Stream,
    alloc: Allocator,

    const Self = @This();
    /// connect to the server
    pub fn connect(alloc: Allocator) !Self {
        const c = try net.tcpConnectToAddress(net.Address.initIp4(.{ 127, 0, 0, 1 }, 6969));
        return Self{ .stream = c, .alloc = alloc };
    }

    /// Send a ping request to the server.
    pub fn ping(self: *Self) !void {
        const req = try request.Request.ping(self.alloc, null, 0, .{});
        const w = self.stream.writer();
        try req.write_to_writer(w);
    }
};
