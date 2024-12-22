const std = @import("std");
const Allocator = std.mem.Allocator;
const version = @import("version.zig");

pub const ResponseCode = enum(u8) {
    Ok = 0,
    DBNotFound = 1,
    CollNotFound = 2,
    BadRequest = 3,
    OldVersoin = 4,
    PermissionDenied = 5,
};

//8 bytes
pub const ResponseHeader = packed struct {
    version: version.Version = version.version, //3 bytes
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
    pub fn old_version(alloc: Allocator) Self {
        return Self.no_body(alloc, .OldVersoin);
    }
    pub fn permission_denied(alloc: Allocator) Self {
        return Self.no_body(alloc, .PermissionDenied);
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
    const rq = try Response.ok(alloc, 255);
    defer rq.deinit();
    const expect = &[_]u8{ 0x32, 0x35, 0x35 };
    try std.testing.expectEqualSlices(u8, expect, rq.body);
}
test "test serialize ok" {
    const alloc = std.testing.allocator;
    const rq = try Response.ok(alloc, 255);
    defer rq.deinit();
    const expect = &[_]u8{ 0, 0, 1, 3, 0, 0, 0, 0, 0x32, 0x35, 0x35 };
    const r = try rq.serialize();
    defer alloc.free(r);
    try std.testing.expectEqualSlices(u8, expect, r);
}
test "test serialize permission denied" {
    const alloc = std.testing.allocator;
    const rq = Response.permission_denied(alloc);
    defer rq.deinit();
    const expect = &[_]u8{ 0, 0, 1, 0, 0, 0, 0, 5 };
    const r = try rq.serialize();
    defer alloc.free(r);
    try std.testing.expectEqualSlices(u8, expect, r);
}
