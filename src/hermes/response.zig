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

pub const ResponseHeader = struct {
    version: version.Version = version.version,
    code: ResponseCode,
    len: u32,
};

pub const Response = struct {
    header: ResponseHeader,
    body: []u8,
    alloc: Allocator,
};
