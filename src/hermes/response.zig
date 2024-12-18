const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList(u8);
const version = @import("common.zig").version;
const Version = @import("common.zig").Version;

pub const ResponseCode = enum(u8) {
    OK = 0,
    BADREQUEST = 1,
    RESOURCENOTFOUND = 2,
    UNAUTHORIZED = 3,
    CLIENTOUTOFDATE = 4,
    INTERNALSERVERERROR = 5,
};

pub const Response = struct {
    version: Version,
    status: ResponseCode,
    len: u32,
    data: []u8,

    alloc: Allocator,

    const Self = @This();

    fn bare(alloc: Allocator, payload: anytype, status: ResponseCode) !Self {
        if (payload == null) {
            return Self{ .version = version, .status = status, .len = 0, .data = try alloc.alloc(u8, 0), .alloc = alloc };
        }
        const tmp = try std.json.stringifyAlloc(alloc, payload, .{});
        return Self{ .version = version, .status = status, .len = tmp.len, .data = tmp, .alloc = alloc };
    }

    pub fn ok(alloc: Allocator, payload: anytype) !Self {
        return try Self.bare(alloc, payload, .OK);
    }
    pub fn bad_request(alloc: Allocator) !Self {
        return try Self.bare(alloc, null, .BADREQUEST);
    }
    pub fn resource_not_found(alloc: Allocator) !Self {
        return try Self.bare(alloc, null, .RESOURCENOTFOUND);
    }
    pub fn unauthorized(alloc: Allocator) !Self {
        return try Self.bare(alloc, null, .UNAUTHORIZED);
    }
    pub fn client_out_of_date(alloc: Allocator) !Self {
        return try Self.bare(alloc, version, .CLIENTOUTOFDATE);
    }
    pub fn internal_server_error(alloc: Allocator) !Self {
        return try Self.bare(alloc, null, .INTERNALSERVERERROR);
    }

    pub fn encode(self: *const Self) ![]u8 {
        var tmp = List.init(self.alloc);
        const w = tmp.writer();
        try self.write_to_writer(w);
        return try tmp.toOwnedSlice();
    }

    pub fn write_to_writer(self: *const Self, writer: anytype) !void {
        try writer.writeInt(u8, version.major, .little);
        try writer.writeInt(u8, version.minor, .little);
        try writer.writeInt(u8, version.patch, .little);
        try writer.writeInt(u8, @intFromEnum(self.status), .little);
        try writer.writeInt(u32, self.len, .little);
        try writer.writeAll(self.data);
    }

    pub fn deinit(self: *const Self) void {
        self.alloc.free(self.data);
    }
};

test "test encode" {
    const alloc = std.testing.allocator;
    const rsp = try Response.bad_request(alloc);
    defer rsp.deinit();
    const enc = try rsp.encode();
    defer alloc.free(enc);

    const excpect = &[_]u8{ 0, 0, 1, 1, 0, 0, 0, 0 };
    try std.testing.expectEqualSlices(u8, excpect, enc);
}
