const std = @import("std");
const db = @import("db.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var sig = std.Thread.ResetEvent{};
    const d = try db.AthenaDB.start(alloc, &sig);
    _ = d;
}

test {
    std.testing.refAllDecls(@This());
}
