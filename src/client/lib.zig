const std = @import("std");
const hermes = @import("hermes");
const Response = hermes.response.Response;
const Request = hermes.request.Request;
const version = hermes.version;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const Client = struct {
    stream: std.net.Stream,

    alloc: Allocator,

    const Self = @This();

    pub fn connect(alloc: Allocator, addr: std.net.Address) !Self {
        const stream = try std.net.tcpConnectToAddress(addr);
        return Self{ .stream = stream, .alloc = alloc };
    }

    pub fn ping(self: *const Self) !u64 {
        const rq = try Request.ping(self.alloc, 0, 0);
        const start = try std.time.Instant.now();

        try self.stream.writeAll(try rq.serialize());
        const r = self.stream.reader();
        const rsp = try Response.from_reader(self.alloc, r);

        assert(std.meta.eql(Response.ok(self.alloc, "Pong"), rsp));

        const end = try std.time.Instant.now();

        return end.since(start);
    }
};

test {
    std.testing.refAllDecls(@This());
}
