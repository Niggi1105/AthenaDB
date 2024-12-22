const std = @import("std");
const hermes = @import("hermes");
const net = std.net;
const Allocator = std.mem.Allocator;
const log = std.log;
const WaitGroup = std.Thread.WaitGroup;
const Pool = std.Thread.Pool;

pub const NetworkInterface = struct {
    addr: net.Address,
    alloc: Allocator,

    const Self = @This();
    pub fn init(alloc: Allocator, addr: net.Address) !Self {
        return Self{ .addr = addr, .alloc = alloc };
    }
    pub fn start(self: *Self) !void {
        var pool: Pool = undefined;
        try Pool.init(&pool, .{ .allocator = self.alloc });
        log.info("starting network interface...", .{});

        var server = try self.addr.listen(.{});

        while (server.accept()) |conn| {
            log.info("accepted connection from: {}...", .{conn.address});
            try pool.spawn(handle_request, .{conn});
        } else |err| {
            log.err("can't accept connection: {}", .{err});
        }
    }
    fn handle_request(conn: std.net.Server.Connection) void {
        _ = conn;
    }
    pub fn deinit(self: Self) void {
        self.pool.deinit();
    }
};
