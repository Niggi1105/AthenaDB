pub const request = @import("request.zig");
pub const response = @import("response.zig");
const std = @import("std");

pub const Version = packed struct {
    major: u8,
    minor: u8,
    patch: u8,
};

pub const version = Version{ .major = 0, .minor = 0, .patch = 1 };

test {
    std.testing.refAllDecls(@This());
}
