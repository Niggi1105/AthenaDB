const std = @import("std");
const hermes = @import("hermes");
const log = std.log;
const Response = hermes.response.Response;
const Request = hermes.request.Request;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const ServerError = error{
    OutOfMemory,
};

fn generate_key() u32 {
    var r = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
    return @truncate(r.next());
}

pub const AthenaCore = struct {
    mutex: std.Thread.Mutex,
    base_dir: std.fs.Dir,

    alloc: Allocator,

    const Self = @This();

    fn handle_get_req(self: *Self, rq: Request) !Response {
        log.debug("got get request...", .{});

        self.mutex.lock();
        defer self.mutex.unlock();

        var buf = ArrayList(u8).init(self.alloc);
        defer buf.deinit();
        try std.fmt.formatInt(rq.header.key, 10, .lower, .{}, buf.writer());

        const file = try self.base_dir.openFile(buf.items, .{ .mode = .read_only });
        defer file.close();
        const content = try file.readToEndAlloc(self.alloc, std.math.maxInt(usize));

        log.debug("sending get response...", .{});

        return Response.ok(content, self.alloc, 0);
    }
    fn handle_put_req(self: *Self, rq: Request) !Response {
        log.debug("got put request...", .{});

        self.mutex.lock();
        defer self.mutex.unlock();

        const key: u32 = generate_key();
        var buf = ArrayList(u8).init(self.alloc);
        defer buf.deinit();
        try std.fmt.formatInt(key, 10, .lower, .{}, buf.writer());

        const file = try self.base_dir.createFile(buf.items, .{});
        defer file.close();
        try file.writeAll(rq.body);

        log.debug("sending put response...", .{});
        return Response.ok(&[_]u8{}, self.alloc, key);
    }

    fn return_err(e: anyerror, conn: std.net.Server.Connection, alloc: Allocator) !void {
        const r = Response.err(@errorName(e), alloc);
        try r.encode(conn.stream.writer());
    }

    pub fn handle_conn(self: *AthenaCore, conn: std.net.Server.Connection) void {
        while (true) {
            const rq = Request.from_reader(self.alloc, conn.stream.reader()) catch |err| {
                if (err == error.EndOfStream) {
                    conn.stream.close();
                    return;
                }
                Self.return_err(err, conn, self.alloc) catch |e| {
                    conn.stream.close();
                    _ = e catch {};
                    return;
                };
                unreachable;
            };
            defer rq.deinit();

            const rsp = switch (rq.header.method) {
                .Get => self.handle_get_req(rq) catch unreachable,
                .Put => self.handle_put_req(rq) catch unreachable,
                .Disconnect => return,
            };

            rsp.encode(conn.stream.writer()) catch unreachable;
        }
    }
};
test {
    std.testing.refAllDecls(@This());
}
