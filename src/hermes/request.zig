const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

pub const RequestFlags = packed struct {
    keepalive: bool,
    _padding: u31 = 0,
};

pub const RequestCode = enum(u8) {
    PING = 0,
    GET = 1,
    STORE = 2,
    UPDATE = 3,
    DELETE = 4,

    NEWDB = 5,
    DELETEDB = 6,
    LISTDBS = 7,

    CONNECT = 9,
    DISCONNECT = 10,
    //SINGIN = 5,
    //SINGOUT = 6,
};

pub const Version = packed struct { major: u8, minor: u8, patch: u8 };

pub const version: Version = .{ .major = 0, .minor = 0, .patch = 1 };

pub const Request = struct {
    version: Version,
    request: RequestCode,
    db_id: u64, //unique identifier for db
    flags: RequestFlags,
    len: u32,
    data: []u8,

    const Self = @This();

    fn bare(alloc: Allocator, obj: anytype, request: RequestCode, db_id: u64, flags: RequestFlags) !Self {
        if (obj == null) {
            const tmp = try alloc.alloc(u8, 0);
            return .{ .version = version, .request = request, .db_id = db_id, .flags = flags, .len = 0, .data = tmp };
        }
        const data = try json.stringifyAlloc(alloc, obj, .{});
        return .{ .version = version, .request = request, .db_id = db_id, .flags = flags, .len = @intCast(data.len), .data = data };
    }

    pub fn get(alloc: Allocator, filter: anytype, db_id: u64, flags: RequestFlags) !Self {
        std.debug.assert(db_id != 0);
        return Self.bare(
            alloc,
            filter,
            .GET,
            db_id,
            flags,
        );
    }

    pub fn store(alloc: Allocator, obj: anytype, db_id: u64, flags: RequestFlags) !Self {
        std.debug.assert(db_id != 0);
        std.debug.assert(obj != null);
        return Self.bare(
            alloc,
            obj,
            .STORE,
            db_id,
            flags,
        );
    }

    pub fn update(alloc: Allocator, filter: anytype, obj: anytype, db_id: u64, flags: RequestFlags) !Self {
        std.debug.assert(obj != null);
        std.debug.assert(filter != null);
        std.debug.assert(db_id != 0);

        const jsflt = try json.stringifyAlloc(alloc, filter, .{});
        const jsobj = try json.stringifyAlloc(alloc, obj, .{});

        var tmp = std.ArrayList(u8).fromOwnedSlice(alloc, jsflt);
        try tmp.appendSlice(jsobj);

        const data = try tmp.toOwnedSlice();

        std.debug.assert(data.len == jsobj.len + jsflt.len);

        return .{ .version = version, .request = .UPDATE, .db_id = db_id, .flags = flags, .len = @intCast(data.len), .data = data };
    }

    pub fn delete(alloc: Allocator, filter: anytype, db_id: u64, flags: RequestFlags) !Self {
        std.debug.assert(db_id != 0);
        return Self.bare(alloc, filter, .DELETE, db_id, flags);
    }

    pub fn ping(alloc: Allocator, obj: anytype, db_id: u64, flags: RequestFlags) !Self {
        return Self.bare(alloc, obj, .PING, db_id, flags);
    }

    pub fn list_dbs(flags: RequestFlags) Self {
        return Self{ .request = .LISTDBS, .data = .{}, .len = 0, .flags = flags, .version = version, .db_id = 0 };
    }
    pub fn delete_db(db_id: u64, flags: RequestFlags) Self {
        return Self{ .request = .DELETEDB, .data = .{}, .len = 0, .flags = flags, .version = version, .db_id = db_id };
    }

    pub fn new_db(db_id: u64, name: []u8, flags: RequestFlags) Self {
        return Self{ .request = .NEWDB, .data = name, .len = name.len, .flags = flags, .version = version, .db_id = db_id };
    }

    pub fn disconnect(flags: RequestFlags) Self {
        return Self{ .request = .DISCONNECT, .data = .{}, .len = 0, .flags = flags, .version = version, .db_id = 0 };
    }

    pub fn connect(flags: RequestFlags) Self {
        return Self{ .request = .CONNECT, .data = .{}, .len = 0, .flags = flags, .version = version, .db_id = 0 };
    }

    pub fn encode(self: *Self, alloc: Allocator) ![]u8 {
        var tmp = std.ArrayList(u8).init(alloc);
        defer tmp.deinit();
        const w = tmp.writer();
        try self.write_to_writer(w);
        return try tmp.toOwnedSlice();
    }

    ///make sure to drop the request after this
    pub fn write_to_writer(self: *Self, writer: anytype) !void {
        try writer.writeInt(u8, self.version.major, .little);
        try writer.writeInt(u8, self.version.minor, .little);
        try writer.writeInt(u8, self.version.patch, .little);
        try writer.writeInt(u8, @intFromEnum(self.request), .little);
        try writer.writeInt(u64, self.db_id, .little);
        try writer.writeStruct(self.flags);
        try writer.writeInt(u32, self.len, .little);
        try writer.writeAll(self.data);
    }
};

test "test write_to_writer" {
    const alloc = std.testing.allocator;

    var rq = try Request.get(alloc, null, 1, .{ .keepalive = true });
    var l = std.ArrayList(u8).init(alloc);
    const w = l.writer();
    try rq.write_to_writer(w);
    const r = try l.toOwnedSlice();
    defer alloc.free(r);

    var tmp = &[_]u8{ 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 };

    try std.testing.expectEqual(r.len, tmp.len);
    try std.testing.expectEqualSlices(u8, tmp[0..], r);
}

test "test write_to_writer_2" {
    const alloc = std.testing.allocator;

    var rq = try Request.ping(alloc, null, 255, .{ .keepalive = true });
    var l = std.ArrayList(u8).init(alloc);
    const w = l.writer();
    try rq.write_to_writer(w);
    const r = try l.toOwnedSlice();
    defer alloc.free(r);

    var tmp = &[_]u8{ 0, 0, 1, 0, 0xFF, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0 };

    try std.testing.expectEqual(r.len, tmp.len);
    try std.testing.expectEqualSlices(u8, tmp[0..], r);
}
