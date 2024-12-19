const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const version = @import("common.zig").version;
const Version = @import("common.zig").Version;

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

pub const RequestHeader = packed struct {
    version: Version,
    request: RequestCode,
    db_id: u64, //unique identifier for db
    flags: RequestFlags,
    len: u32,
    _padding: u96 = 0,
};

pub const Request = struct {
    header: RequestHeader,
    data: []u8,

    alloc: Allocator,

    const Self = @This();

    fn bare(alloc: Allocator, obj: anytype, request: RequestCode, db_id: u64, flags: RequestFlags) !Self {
        if (obj == null) {
            const tmp = try alloc.alloc(u8, 0);
            return .{ .header = .{ .version = version, .request = request, .db_id = db_id, .flags = flags, .len = 0 }, .data = tmp, .alloc = alloc };
        }
        const data = try json.stringifyAlloc(alloc, obj, .{});
        return .{ .header = .{ .version = version, .request = request, .db_id = db_id, .flags = flags, .len = @intCast(data.len) }, .data = data, .alloc = alloc };
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

        return .{ .header = .{ .version = version, .request = .UPDATE, .db_id = db_id, .flags = flags, .len = @intCast(data.len) }, .data = data, .alloc = alloc };
    }

    pub fn delete(alloc: Allocator, filter: anytype, db_id: u64, flags: RequestFlags) !Self {
        std.debug.assert(db_id != 0);
        return Self.bare(alloc, filter, .DELETE, db_id, flags);
    }

    pub fn ping(alloc: Allocator, obj: anytype, db_id: u64, flags: RequestFlags) !Self {
        return Self.bare(alloc, obj, .PING, db_id, flags);
    }

    pub fn list_dbs(alloc: Allocator, flags: RequestFlags) Self {
        return Self.bare(alloc, null, .LISTDBS, 0, flags);
    }
    pub fn delete_db(alloc: Allocator, db_id: u64, flags: RequestFlags) Self {
        return Self.bare(alloc, null, .DELETEDB, db_id, flags);
    }

    ///name must be allocated with alloc
    pub fn new_db(alloc: Allocator, db_id: u64, name: ?[]u8, flags: RequestFlags) Self {
        return Self.bare(alloc, name, .NEWDB, db_id, flags);
    }

    pub fn disconnect(alloc: Allocator, flags: RequestFlags) Self {
        return Self.bare(alloc, null, .DISCONNECT, 0, flags);
    }

    pub fn connect(alloc: Allocator, flags: RequestFlags) Self {
        return Self.bare(alloc, null, .CONNECT, 0, flags);
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
        try writer.writeStruct(self.header);
        try writer.writeAll(self.data);
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.data);
    }

    pub fn from_reader(alloc: Allocator, reader: anytype) !Self {
        const header: RequestHeader = try reader.readStruct(RequestHeader);
        const buf = try alloc.alloc(u8, @intCast(header.len));

        const n = try reader.readAll(buf);
        if (n < buf.len) {
            return error.BadRequest;
        }

        return Self{ .header = header, .data = buf, .alloc = alloc };
    }
};

test "test write_to_writer" {
    const alloc = std.testing.allocator;

    var rq = try Request.get(alloc, null, 1, .{ .keepalive = true });
    var l = std.ArrayList(u8).init(alloc);
    const w = l.writer();
    try rq.write_to_writer(w);
    defer rq.deinit();
    const r = try l.toOwnedSlice();
    defer alloc.free(r);

    var tmp = &[_]u8{ 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    try std.testing.expectEqual(r.len, tmp.len);
    try std.testing.expectEqualSlices(u8, tmp[0..], r);
}

test "test encode 1" {
    const alloc = std.testing.allocator;

    var rq = try Request.ping(alloc, null, 255, .{ .keepalive = true });
    defer rq.deinit();
    const r = try rq.encode(alloc);
    defer alloc.free(r);

    var tmp = &[_]u8{ 0, 0, 1, 0, 0xFF, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

    try std.testing.expectEqual(r.len, tmp.len);
    try std.testing.expectEqualSlices(u8, tmp[0..], r);
}

test "test encode 2" {
    const alloc = std.testing.allocator;

    const MyStruct = struct {
        name: []const u8,
        age: u8,
    };
    const p: ?MyStruct = MyStruct{ .age = 16, .name = "Max Mustermann" };

    var rq = try Request.get(alloc, p, 255, .{ .keepalive = true });
    defer rq.deinit();
    const r = try rq.encode(alloc);
    defer alloc.free(r);

    //header
    const header = [32]u8{ 0, 0, 1, 1, 0xFF, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0x22, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    //body
    var bd = std.ArrayList(u8).init(alloc);
    try bd.appendSlice(&header);
    try bd.appendSlice("{\"name\":\"Max Mustermann\",\"age\":16}");
    const res = try bd.toOwnedSlice();

    defer alloc.free(res);

    try std.testing.expectEqual(r.len, res.len);
    try std.testing.expectEqualSlices(u8, res, r);
}
