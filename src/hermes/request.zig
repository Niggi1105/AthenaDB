const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const version = @import("hermes.zig").version;

pub const RequestMethod = enum(u8) {
    Get = 1,
    Put = 2,
    Delete = 3,
    Disconnect = 4,
};

pub const RequestHeader = packed struct { //64
    version: @TypeOf(version) = version, //24
    method: RequestMethod, //8
    len: usize, //32
    key: u32,
};

pub const Request = struct {
    header: RequestHeader,
    body: []u8,
    alloc: Allocator,

    pub fn put(content: []u8, alloc: Allocator) Request {
        return .{ .header = .{ .method = .Put, .len = content.len, .key = 0 }, .body = content, .alloc = alloc };
    }
    pub fn get(key: u32, alloc: Allocator) Request {
        return .{ .header = .{ .method = .Get, .len = 0, .key = key }, .body = &[_]u8{}, .alloc = alloc };
    }
    pub fn delete(key: u32, alloc: Allocator) Request {
        return .{ .header = .{ .method = .Delete, .len = 0, .key = key }, .body = &[_]u8{}, .alloc = alloc };
    }
    pub fn dissconnect(alloc: Allocator) Request {
        return .{ .header = .{ .method = .Disconnect, .len = 0, .key = 0 }, .body = &[_]u8{}, .alloc = alloc };
    }

    pub fn encode(self: *const Request, writer: anytype) !void {
        try writer.writeStructEndian(self.header, .little);
        try writer.writeAll(self.body);
    }

    pub fn decode(bytes: []u8, alloc: Allocator) !Request {
        const header: RequestHeader = std.mem.bytesToValue(RequestHeader, bytes[0..16]);
        if (bytes.len < header.len + 16) {
            return error.MissingBytes;
        }
        return .{ .header = header, .body = bytes[16 .. header.len + 16], .alloc = alloc };
    }

    pub fn from_reader(alloc: Allocator, reader: anytype) !Request {
        const header = try reader.readStructEndian(RequestHeader, .little);
        const buf = try alloc.alloc(u8, header.len);
        _ = try reader.readAll(buf);
        return .{ .header = header, .body = buf, .alloc = alloc };
    }

    pub fn deinit(self: Request) void {
        self.alloc.free(self.body);
    }
};

test "encode-decode" {
    const alloc = std.testing.allocator;
    const s = "Hello World";
    var b = std.mem.toBytes(s);
    const r = Request.put(&b, alloc);

    var arr = ArrayList(u8).init(alloc);
    defer arr.deinit();
    const writer = arr.writer();

    try r.encode(writer);
    const dec = try Request.decode(arr.items[0..], alloc);

    try std.testing.expectEqualSlices(u8, r.body, dec.body);
    try std.testing.expectEqualDeep(r.header, dec.header);
}
