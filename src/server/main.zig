const std = @import("std");
const net = @import("net.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var ni = try net.NetworkInterface.init(alloc, std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3000));
    try ni.start();
}

test {
    std.testing.refAllDecls(@This());
}
