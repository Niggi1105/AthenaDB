const std = @import("std");
const db = @import("db.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var core = db.AthenaCore{};
    const d = try db.AthenaDB.start(alloc, &core);
    _ = d;
}

test {
    std.testing.refAllDecls(@This());
}
