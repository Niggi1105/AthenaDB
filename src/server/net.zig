const std = @import("std");
const hermes = @import("hermes");
const net = std.net;
const Allocator = std.mem.Allocator;
const log = std.log;
const WaitGroup = std.Thread.WaitGroup;
const Pool = std.Thread.Pool;
const request = hermes.request;
const Request = request.Request;
const response = hermes.response;
const Response = response.Response;

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
            try pool.spawn(handle_conn, .{ self.alloc, conn });
        } else |err| {
            log.err("can't accept connection: {}", .{err});
        }
    }

    fn handle_conn(alloc: Allocator, conn: std.net.Server.Connection) void {
        const tmp = Self.serve_request(alloc, conn);
        defer tmp.deinit();

        const bytes: []u8 = tmp.serialize() catch |err| blk: {
            std.log.err("can't serialize Response: {}", .{err});
            //if we can't serialize a static Response we should close the stream and end the connection handle
            break :blk Response.internal_error(alloc).serialize() catch |er| {
                std.log.err("can't serialize static Response: {}. Closing stream and returning...", .{er});
                conn.stream.close();
                return;
            };
        };
        defer alloc.free(bytes);

        conn.stream.writeAll(bytes) catch |err| std.log.err("error when writing to stream: {}", .{err});
    }

    fn serve_request(alloc: Allocator, conn: std.net.Server.Connection) Response {
        const r = conn.stream.reader();

        if (Request.from_reader(alloc, r)) |rq| {
            if (!std.meta.eql(rq.header.version, hermes.version)) {
                return Response.old_version(alloc);
            }
            log.info("got {} request...", .{rq.header.method});
            return switch (rq.header.method) {
                .Ping => Response.ok(alloc, "Pong") catch Response.internal_error(alloc),
                .Get => Response.bad_request(alloc),
                .Put => Response.bad_request(alloc),
                .Delete => Response.bad_request(alloc),
                .NewDB => Response.bad_request(alloc),
                .NewColl => Response.bad_request(alloc),
                .DeleteDB => Response.bad_request(alloc),
                .DeleteColl => Response.bad_request(alloc),
            };
        } else |_| {
            return Response.bad_request(alloc);
        }
    }

    pub fn deinit(self: Self) void {
        self.pool.deinit();
    }
};
