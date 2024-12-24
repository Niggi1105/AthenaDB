const std = @import("std");
const Allocator = std.mem.Allocator;
const version = @import("hermes.zig").version;

pub const RequestMethod = enum(u8) {
    Ping = 0,
    Get = 1,
    Put = 2,
    Delete = 3,
    NewDB = 4,
    NewColl = 5,
    DeleteDB = 6,
    DeleteColl = 7,

    Shutdown = 8,
};

//32 bytes
pub const RequestHeader = packed struct {
    version: @TypeOf(version) = version, //3 bytes
    method: RequestMethod, //1 byte
    db_id: u64, // 8 bytes
    coll_id: u64, // 8 bytes
    len: u32, // 4 bytes
    _padding: u64 = 0, //8 bytes
};

///this type is not supposed to be manually constructed. Please use the functions that were provided
pub const Request = struct {
    header: RequestHeader, //32 bytes
    body: []u8, //n-bytes
    alloc: Allocator,

    const Self = @This();

    fn bare(alloc: Allocator, obj: anytype, db_id: u64, coll_id: u64, method: RequestMethod) !Self {
        if (@TypeOf(obj) == []u8) {
            if (obj.len == 0) {
                const header = RequestHeader{ .method = method, .db_id = db_id, .coll_id = coll_id, .len = 0 };
                return Self{ .header = header, .body = obj, .alloc = alloc };
            }
        }
        const tmp = try std.json.stringifyAlloc(alloc, obj, .{});
        const header = RequestHeader{ .method = method, .db_id = db_id, .coll_id = coll_id, .len = @intCast(tmp.len) };
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
    pub fn put(alloc: Allocator, obj: anytype, db_id: u64, coll_id: u64) !Self {
        return Self.bare(alloc, obj, db_id, coll_id, .Put);
    }
    pub fn delete(alloc: Allocator, filter: anytype, db_id: u64, coll_id: u64) !Self {
        return Self.bare(alloc, filter, db_id, coll_id, .Delete);
    }
    ///make sure that name was allocated with the passed allocator
    pub fn new_db(alloc: Allocator, name: []u8, db_id: u64, coll_id: u64) !Self {
        return Self.bare(alloc, name, db_id, coll_id, .NewDB);
    }
    pub fn new_coll(alloc: Allocator, db_id: u64, coll_id: u64) !Self {
        return Self.bare(alloc, try alloc.alloc(u8, 0), db_id, coll_id, .NewColl);
    }
    pub fn delete_db(alloc: Allocator, db_id: u64, coll_id: u64) !Self {
        return Self.bare(alloc, try alloc.alloc(u8, 0), db_id, coll_id, .DeleteDB);
    }
    pub fn delete_coll(alloc: Allocator, db_id: u64, coll_id: u64) !Self {
        return Self.bare(alloc, try alloc.alloc(u8, 0), db_id, coll_id, .DeleteColl);
    }
    pub fn shutdown(alloc: Allocator, db_id: u64, coll_id: u64) !Self {
        return Self.bare(alloc, try alloc.alloc(u8, 0), db_id, coll_id, .Shutdown);
    }
    pub fn from_reader(alloc: Allocator, reader: anytype) !Self {
        const header: RequestHeader = try reader.readStruct(RequestHeader);
        const buf = try alloc.alloc(u8, header.len);
        const n = try reader.readAll(buf);
        std.debug.assert(n == buf.len);
        return Self{ .header = header, .body = buf, .alloc = alloc };
    }
    ///you still need to call deinit, bc serializes creates a copy
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
