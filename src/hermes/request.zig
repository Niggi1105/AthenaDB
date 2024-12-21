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

pub const Request = struct {
    header: RequestHeader, //24 bytes
    body: []u8, //n-bytes
    alloc: Allocator,

    const Self = @This();
    fn bare(T: type, alloc: Allocator, filter: T, db_id: u64, coll_id: u64, method: RequestMethod) !Self {
        const tmp = try std.json.stringifyAlloc(alloc, filter, .{});
        const header = RequestHeader{ .version = version.version, .method = method, .db_id = db_id, .coll_id = coll_id, .len = @intCast(tmp.len) };
        return Self{ .header = header, .body = tmp, .alloc = alloc };
    }
    pub fn get(T: type, alloc: Allocator, filter: T, db_id: u64, coll_id: u64) !Self {
        return Self.bare(T, alloc, filter, db_id, coll_id, .Get);
    }
    pub fn deinit(self: Self) void {
        self.alloc.free(self.body);
    }
};

test "construct get request" {
    const alloc = std.testing.allocator;
    const rq = try Request.get(u8, alloc, 255, 0, 0);
    defer rq.deinit();
    const expect = &[_]u8{ 0x32, 0x35, 0x35 };
    try std.testing.expectEqualSlices(u8, expect, rq.body);
}
