const std = @import("std");
const net = std.net;
const Allocator = std.mem.Allocator;
const hermes = @import("hermes");
const request = hermes.request;
const response = hermes.response;
const Response = response.Response;

pub const Client = struct {
    stream: net.Stream,
    alloc: Allocator,

    const Self = @This();
    /// connect to the server
    pub fn connect(alloc: Allocator) !Self {
        const c = try net.tcpConnectToAddress(net.Address.initIp4(.{ 127, 0, 0, 1 }, 6969));
        return Self{ .stream = c, .alloc = alloc };
    }

    /// Send a ping request to the server. Returns the roundtriptime
    pub fn ping(self: *const Self) !Response {
        const req = try request.Request.ping(self.alloc, null, 0, .{ .keepalive = false });
        const w = self.stream.writer();
        try req.write_to_writer(w);
        return try response.Response.from_reader(self.alloc, self.stream.reader());
    }

    pub fn shutdown(self: *const Self) !Response {
        const req = try request.Request.shutdown(self.alloc, .{ .keepalive = false });
        const w = self.stream.writer();
        try req.write_to_writer(w);
        return try response.Response.from_reader(self.alloc, self.stream.reader());
    }
};
