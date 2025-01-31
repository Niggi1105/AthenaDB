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

    pub fn connect(alloc: Allocator, addr: std.net.Address) !Client {
        const stream = try std.net.tcpConnectToAddress(addr);
        return Client{ .stream = stream, .alloc = alloc };
    }

    pub fn get(self: Client, key: u32) !Response {
        const rq = Request.get(key, self.alloc);
        try rq.encode(self.stream.writer());
        const rsp = try Response.from_reader(self.alloc, self.stream.reader());
        return rsp;
    }
    pub fn put(self: Client, data: []u8) !Response {
        const rq = Request.put(data, self.alloc);
        try rq.encode(self.stream.writer());
        const rsp = try Response.from_reader(self.alloc, self.stream.reader());
        return rsp;
    }

    pub fn disconnect(self: Client) void {
        self.stream.close();
    }
};

test {
    std.testing.refAllDecls(@This());
    const alloc = std.testing.allocator;
    const client = try Client.connect(alloc, std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));
    const data = "Hello World";
    var slice = std.mem.toBytes(data);
    const rsp = try client.put(&slice);
    defer rsp.deinit();
    const rsp2 = try client.get(rsp.header.key);
    defer rsp2.deinit();

    unreachable;

    //try std.testing.expectEqualSlices(u8, rsp2.body, &slice);
}
