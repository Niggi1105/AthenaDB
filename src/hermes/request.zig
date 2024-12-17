const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

const version: [3]u8 = .{ 0, 0, 1 };

pub const RequestFlags = packed struct {
    keepalive: bool,
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

pub const Request = packed struct {
    version: [3]u8,
    request: RequestCode,
    db_id: u64, //unique identifier for db
    flags: RequestFlags,
    len: u32,
    data: []u8,

    const Self = @This();

    fn bare(alloc: Allocator, obj: anytype, request: RequestCode, db_id: u64, flags: RequestFlags) !Self {
        const data = try json.stringifyAlloc(alloc, obj, .{});
        return .{ .version = version, .request = request, .db_id = db_id, .flags = flags, .len = data.len, .data = data };
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

        return .{ .version = version, .request = .UPDATE, .db_id = db_id, .flags = flags, .len = data.len, .data = data };
    }

    pub fn delete(alloc: Allocator, filter: anytype, db_id: u64, flags: RequestFlags) !Self {
        std.debug.assert(db_id != 0);
        return Self.bare(alloc, filter, .DELETE, db_id, flags);
    }

    pub fn ping(alloc: Allocator, obj: anytype, db_id: u64, flags: RequestFlags) !Self {
        return Self.bare(alloc, obj, .PING, db_id, flags);
    }

    pub fn disconnect() Self {
        return Self{ .request = .DISCONNECT, .data = .{}, .len = 0, .flags = .{ .flags = 0 }, .version = version, .db_id = 0 };
    }

    pub fn list_dbs() Self {
        return Self{ .request = .LISTDBS, .data = .{}, .len = 0, .flags = .{ .flags = 0 }, .version = version, .db_id = 0 };
    }
    pub fn delete_db(db_id: u64) Self {
        return Self{ .request = .DELETEDB, .data = .{}, .len = 0, .flags = .{ .flags = 0 }, .version = version, .db_id = db_id };
    }

    pub fn new_db(db_id: u64, name: []u8) Self {
        return Self{ .request = .DELETEDB, .data = name, .len = name.len, .flags = .{ .flags = 0 }, .version = version, .db_id = db_id };
    }

    pub fn encode(self: *Self, alloc: Allocator) ![]u8 {
        var tmp = std.ArrayList(u8).init(alloc);
        const w = tmp.writer();
        try self.write_to_writer(w);
        return try tmp.toOwnedSlice();
    }

    pub fn write_to_writer(self: *Self, writer: anytype) !void {
        try writer.writeAll(self.version);
        try writer.writeInt(u8, self.request, .little);
        try writer.writeInt(u64, self.db_id, .little);
        try writer.writeStructEndian(self.flags, .little);
        try writer.writeInt(u32, self.len, .little);
        try writer.writeAll(self.data);
    }
};
