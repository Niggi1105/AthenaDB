const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const version = @import("hermes.zig").version;

pub const ResponseCode = enum(u8) {
    Ok = 0,
    Error = 1,
};

//8 bytes
pub const ResponseHeader = packed struct {
    version: @TypeOf(version) = version, //3 bytes
    len: usize, //4 bytes
    code: ResponseCode, //1 byte
    key: u32 = 0, //the id of the record
};

pub const Response = struct {
    header: ResponseHeader,
    body: []u8,
    alloc: Allocator,

    pub fn ok(content: []u8, alloc: Allocator, key: u32) Response {
        return .{ .header = .{ .len = content.len, .code = .Ok, .key = key }, .body = content, .alloc = alloc };
    }

    pub fn err(error_msg: []u8, alloc: Allocator) Response {
        return .{ .header = .{ .len = error_msg.len, .code = .Error, .key = 0 }, .body = error_msg, .alloc = alloc };
    }

    pub fn encode(self: *const Response, w: anytype) !void {
        try w.writeStructEndian(self.header, .little);
        try w.writeAll(self.body);
    }

    pub fn decode(bytes: []u8, alloc: Allocator) !Response {
        const header: ResponseHeader = std.mem.bytesToValue(ResponseHeader, bytes[0..16]);
        if (bytes.len < header.len + 16) {
            return error.MissingBytes;
        }
        return Response{ .header = header, .body = bytes[16 .. header.len + 16], .alloc = alloc };
    }

    pub fn from_reader(alloc: Allocator, reader: anytype) !Response {
        const header = try reader.readStructEndian(ResponseHeader, .little);
        const buf = try alloc.alloc(u8, header.len);
        _ = try reader.readAll(buf);
        return .{ .header = header, .body = buf, .alloc = alloc };
    }

    pub fn deinit(self: Response) void {
        self.alloc.free(self.body);
    }
};

test "encode-decode" {
    const alloc = std.testing.allocator;
    const s = "Hello World";
    var b = std.mem.toBytes(s);
    const r = Response.ok(&b, alloc, 0);

    var arr = ArrayList(u8).init(alloc);
    defer arr.deinit();
    const w = arr.writer();

    try r.encode(w);
    const dec = try Response.decode(arr.items[0..], alloc);

    try std.testing.expectEqualSlices(u8, r.body, dec.body);
    try std.testing.expectEqualDeep(r.header, dec.header);
}
