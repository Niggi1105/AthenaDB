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
    pub fn delete(self: Client, key: u32) !Response {
        const rq = Request.delete(key, self.alloc);
        try rq.encode(self.stream.writer());
        const rsp = try Response.from_reader(self.alloc, self.stream.reader());
        return rsp;
    }

    pub fn disconnect(self: Client) !void {
        const rq = Request.dissconnect(self.alloc);
        try rq.encode(self.stream.writer());
        self.stream.close();
    }
};

test {
    std.testing.refAllDecls(@This());
    const alloc = std.testing.allocator;
    const client = try Client.connect(alloc, std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));
    const data = "Hello World!!";

    var slice = std.mem.toBytes(data.*);
    const rsp = try client.put(&slice);
    defer rsp.deinit();
    try std.testing.expect(rsp.header.code == .Ok);

    const rsp2 = try client.get(rsp.header.key);
    defer rsp2.deinit();

    const rsp3 = try client.delete(rsp.header.key);
    defer rsp3.deinit();
    try std.testing.expect(rsp2.header.code == .Ok);

    try client.disconnect();

    try std.testing.expect(rsp2.header.code == .Ok);
    try std.testing.expectEqualSlices(u8, &slice, rsp2.body);
}
