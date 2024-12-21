const std = @import("std");
const Allocator = std.mem.Allocator;
const version = @import("version.zig");

pub const RequestMethod = enum(u8) {
    Ping = 0,
    Get = 1,
    Put = 2,
    Delete = 3,
    NewDB = 4,
    NewColl = 5,
};

//24 bytes
pub const RequestHeader = packed struct {
    version: version.Version, //3 bytes
    method: RequestMethod, //1 byte
    db_id: u64, // 8 bytes
    coll_id: u64, // 8 bytes
    len: u32, // 4 bytes
};

///this type is not supposed to be manually constructed. Please use the functions that were provided
pub const Request = struct {
    header: RequestHeader, //24 bytes
    body: []u8, //n-bytes
    alloc: Allocator,

    const Self = @This();

    fn bare(alloc: Allocator, obj: anytype, db_id: u64, coll_id: u64, method: RequestMethod) !Self {
        if (@TypeOf(obj) == []u8) {
            if (obj.len == 0) {
                const header = RequestHeader{ .version = version.version, .method = method, .db_id = db_id, .coll_id = coll_id, .len = 0 };
                return Self{ .header = header, .body = obj, .alloc = alloc };
            }
        }
        const tmp = try std.json.stringifyAlloc(alloc, obj, .{});
        const header = RequestHeader{ .version = version.version, .method = method, .db_id = db_id, .coll_id = coll_id, .len = @intCast(tmp.len) };
        return Self{ .header = header, .body = tmp, .alloc = alloc };
    }
    pub fn ping(alloc: Allocator, db_id: u64, coll_id: u64) !Self {
        return Self.bare(alloc, "Ping", db_id, coll_id, .Ping);
    }
    /// T has to be non null.
    /// to get all entries simply pass an empty slice
    pub fn get(alloc: Allocator, filter: anytype, db_id: u64, coll_id: u64) !Self {
        return Self.bare(alloc, filter, db_id, coll_id, .Get);
    }
    pub fn put(alloc: Allocator, key: anytype, value: anytype, db_id: u64, coll_id: u64) !Self {}
    pub fn deinit(self: Self) void {
        self.alloc.free(self.body);
    }
};

test "construct Ping" {
    const alloc = std.testing.allocator;
    const rq = try Request.ping(alloc, 0, 0);
    defer rq.deinit();
    const expect = &[_]u8{ 0x22, 0x50, 0x69, 0x6E, 0x67, 0x22 };
    try std.testing.expectEqualSlices(u8, expect, rq.body);
}

test "construct get request normal" {
    const alloc = std.testing.allocator;
    const rq = try Request.get(alloc, 255, 0, 0);
    defer rq.deinit();
    const expect = &[_]u8{ 0x32, 0x35, 0x35 };
    try std.testing.expectEqualSlices(u8, expect, rq.body);
}
test "construct get request empty" {
    const alloc = std.testing.allocator;
    const tmp = try alloc.alloc(u8, 0);
    const rq = try Request.get(alloc, tmp, 0, 0);
    defer rq.deinit();
    try std.testing.expectEqual(0, rq.header.len);
    try std.testing.expectEqualSlices(u8, tmp, rq.body);
}
