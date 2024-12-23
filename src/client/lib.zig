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

    pub fn ping(self: *const Self) !void {
        const rq = try Request.ping(self.alloc, 0, 0);
        defer rq.deinit();
        const bytes = try rq.serialize();

        defer self.alloc.free(bytes);
        try self.stream.writeAll(bytes);

        const r = self.stream.reader();
        const rsp = try Response.from_reader(self.alloc, r);
        defer rsp.deinit();

        const expect = try Response.ok(self.alloc, "Pong");
        std.debug.assert(std.meta.eql(expect.header, rsp.header));
        std.debug.assert(std.mem.eql(u8, expect.body, rsp.body));
    }

    pub fn disconnect(self: *Self) void {
        self.stream.close();
    }
};

test {
    std.testing.refAllDecls(@This());
}
