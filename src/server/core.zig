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
        log.info("got get request...", .{});
        const file = try self.base_dir.createFile(&std.mem.toBytes(rq.header.key), .{});
        try file.lock(.exclusive);
        const content = try file.readToEndAlloc(self.alloc, std.math.maxInt(usize));
        log.info("sending get response...", .{});
        return Response.ok(content, self.alloc, 0);
    }
    fn handle_put_req(self: *Self, rq: Request) !Response {
        log.info("got put request...", .{});
        const key: u32 = generate_key();
        const file = try self.base_dir.createFile(&std.mem.toBytes(key), .{});
        try file.lock(.exclusive);
        try file.writeAll(rq.body);
        log.info("sending put response...", .{});
        return Response.ok(&[_]u8{}, self.alloc, key);
    }

    pub fn handle_conn(self: *AthenaCore, conn: std.net.Server.Connection) void {
        const rq = Request.from_reader(self.alloc, conn.stream.reader()) catch unreachable;
        defer rq.deinit();

        const rsp = switch (rq.header.method) {
            .Get => self.handle_get_req(rq) catch unreachable,
            .Put => self.handle_put_req(rq) catch unreachable,
        };

        var buf = ArrayList(u8).init(self.alloc);
        defer buf.deinit();

        rsp.encode(buf.writer()) catch unreachable;

        _ = conn.stream.writeAll(buf.items) catch unreachable;
    }
};
test {
    std.testing.refAllDecls(@This());
}
