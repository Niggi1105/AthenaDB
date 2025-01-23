const std = @import("std");
const db = @import("db.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    try db.AthenaDB.start(alloc);
}

test {
    std.testing.refAllDecls(@This());
}
