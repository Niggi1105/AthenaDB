const std = @import("std");
const hermes = @import("hermes");
const Response = hermes.response.Response;
const Request = hermes.request.Request;
const version = hermes.version;
const Allocator = std.mem.Allocator;

pub const Client = struct {
    stream: std.net.Stream,

    alloc: Allocator,

    const Self = @This();

    pub fn connect(alloc: Allocator, addr: std.net.Address) !Self {
        const stream = try std.net.tcpConnectToAddress(addr);
        return Self{ .stream = stream, .alloc = alloc };
    }

    pub fn get(filter: anytype) !Response {
        _ = filter;
    }
};

test {
    std.testing.refAllDecls(@This());
}
