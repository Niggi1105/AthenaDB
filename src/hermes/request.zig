const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

pub const RequestFlags = struct {
    flags: u32,

    const Self = @This();
    pub fn empty() Self {
        return .{ .flags = 0 };
    }
    pub fn keep_alive(self: *Self, state: bool) void {
        if (state) {
            self.flags = self.flags | (1 << 31);
        } else {
            self.flags = self.flags & (1 <<| 30);
        }
    }
};

test "bit flags" {
    var f = RequestFlags.empty();
    f.keep_alive(true);
    try std.testing.expectEqual(f.flags, std.math.pow(u32, 2, 31));
    f.keep_alive(false);
    try std.testing.expectEqual(f.flags, 0);
}

pub const Request = struct {
    version: [3]u8,
    request: u8,
    flags: RequestFlags,
    len: usize,
    data: []u8,

    const Self = @This();

    fn bare(alloc: Allocator, obj: anytype) !Self {
        const data = try json.stringifyAlloc(alloc, obj, .{});
        return .{ .version = .{ 0, 0, 1 }, .request = 1, .flags = .{ .flags = 0 }, .len = data.len, .data = data };
    }

    pub fn get(alloc: Allocator, obj: anytype, options: RequestFlags) !Self {
        _ = options;
        return Self.bare(alloc, obj);
    }
};
