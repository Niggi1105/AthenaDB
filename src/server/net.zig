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
    pool: Pool,

    const Self = @This();
    pub fn init(alloc: Allocator, addr: net.Address) !Self {
        var pool: Pool = undefined;
        try Pool.init(&pool, .{ .allocator = alloc });
        return Self{ .addr = addr, .alloc = alloc, .pool = pool };
    }
    pub fn start(self: *Self) !void {
        log.info("starting network interface...", .{});
        var wait_group: WaitGroup = undefined;
        wait_group.reset();
        while (self.addr.listen(.{})) |server| {
            try self.pool.spawn(handle_request, .{ &wait_group, server });
        } else |err| {
            log.err("can't listen to addr: {}", .{err});
        }
        self.pool.waitAndWork(&wait_group);
    }
    fn handle_request(wait_group: *WaitGroup, server: std.net.Server) void {
        wait_group.start();
        defer wait_group.finish();
        _ = server;
    }
    pub fn deinit(self: Self) void {
        self.pool.deinit();
    }
};
