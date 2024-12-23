const std = @import("std");
const Allocator = std.mem.Allocator;
const version = @import("hermes.zig").version;
const Version = @import("hermes.zig").Version;

pub const ResponseCode = enum(u8) {
    Ok = 0,
    DBNotFound = 1,
    CollNotFound = 2,
    BadRequest = 3,
    Incompatible = 4,
    PermissionDenied = 5,
    InternalError = 6,
};

//8 bytes
pub const ResponseHeader = packed struct {
    version: @TypeOf(version) = version, //3 bytes
    len: u32, //4 bytes
    code: ResponseCode, //1 byte
};

pub const Response = struct {
    header: ResponseHeader,
    body: []u8,
    alloc: Allocator,

    const Self = @This();

    fn no_body(alloc: Allocator, code: ResponseCode) Self {
        const tmp = &[_]u8{};
        return Self{ .header = .{ .len = 0, .code = code }, .body = tmp[0..], .alloc = alloc };
    }
    pub fn ok(alloc: Allocator, val: anytype) !Self {
        const tmp = try std.json.stringifyAlloc(alloc, val, .{});
        const header = ResponseHeader{ .len = @intCast(tmp.len), .code = .Ok };
        return Self{ .header = header, .body = tmp, .alloc = alloc };
    }
    pub fn db_not_found(alloc: Allocator) Self {
        return Self.no_body(alloc, .DBNotFound);
    }
    pub fn coll_not_found(alloc: Allocator) Self {
        return Self.no_body(alloc, .CollNotFound);
    }
    pub fn bad_request(alloc: Allocator) Self {
        return Self.no_body(alloc, .BadRequest);
    }
    pub fn incompatible(alloc: Allocator) Self {
        return Self.no_body(alloc, .Incompatible);
    }
    pub fn permission_denied(alloc: Allocator) Self {
        return Self.no_body(alloc, .PermissionDenied);
    }
    pub fn internal_error(alloc: Allocator) Self {
        return Self.no_body(alloc, .InternalError);
    }
    pub fn from_reader(alloc: Allocator, reader: anytype) !Self {
        const header: ResponseHeader = try reader.readStruct(ResponseHeader);
        const buf = try alloc.alloc(u8, @intCast(header.len));
        const n = try reader.readAll(buf);
        std.debug.assert(n == buf.len);
        return Self{ .header = header, .body = buf, .alloc = alloc };
    }
    pub fn deserialize(alloc: Allocator, slice: []u8) !Self {
        defer alloc.free(slice);

        const v = Version{ .major = slice[0], .minor = slice[1], .patch = slice[2] };
        const len = std.mem.bytesToValue(u32, slice[3..7]);
        const code: ResponseCode = @enumFromInt(slice[7]);
        const header = ResponseHeader{ .version = v, .len = len, .code = code };

        std.debug.assert(slice.len == @as(usize, 8 + len));
        var body = try alloc.alloc(u8, @intCast(len));
        @memcpy(body[0..], slice[8..]);

        return Self{ .header = header, .body = body, .alloc = alloc };
    }

    pub fn serialize(self: *const Self) ![]u8 {
        var tmp = std.ArrayList(u8).init(self.alloc);
        const w = tmp.writer();
        try w.writeStruct(self.header);
        try w.writeAll(self.body);
        return tmp.toOwnedSlice();
    }

    pub fn deinit(self: Self) void {
        self.alloc.free(self.body);
    }
};
test "construct ok" {
    const alloc = std.testing.allocator;
    const rp = try Response.ok(alloc, 255);
    defer rp.deinit();
    const expect = &[_]u8{ 0x32, 0x35, 0x35 };
    try std.testing.expectEqualSlices(u8, expect, rp.body);
}
test "test serialize ok" {
    const alloc = std.testing.allocator;
    const rp = try Response.ok(alloc, 255);
    defer rp.deinit();
    const expect = &[_]u8{ 0, 0, 1, 3, 0, 0, 0, 0, 0x32, 0x35, 0x35 };
    const r = try rp.serialize();
    defer alloc.free(r);
    try std.testing.expectEqualSlices(u8, expect, r);
}
test "test serialize permission denied" {
    const alloc = std.testing.allocator;
    const rp = Response.permission_denied(alloc);
    defer rp.deinit();
    const expect = &[_]u8{ 0, 0, 1, 0, 0, 0, 0, 5 };
    const r = try rp.serialize();
    defer alloc.free(r);
    try std.testing.expectEqualSlices(u8, expect, r);
}

test "test serialize, deserialize ok" {
    const alloc = std.testing.allocator;
    const rp = try Response.ok(alloc, "foo");
    defer rp.deinit();

    const s = try rp.serialize();
    const r = try Response.deserialize(alloc, s);
    defer r.deinit();

    try std.testing.expectEqualDeep(rp, r);
}
