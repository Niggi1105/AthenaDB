const std = @import("std");
const Allocator = std.mem.Allocator;

pub const HeaderFlags = std.StaticBitSet(24){};
// uses the following protocol:
// packet: header | payload
// -----------------------------------------------
// 3 bytes: version
// 4 bytes: len of payload
// 4 bytes: checksum
// 3 bytes: flags
// 1 byte: status
// 1 byte: Request type
pub fn Encoder(T: type) type {
    return struct {
        const Self = @This();
    };
}
