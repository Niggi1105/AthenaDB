const std = @import("std");
const hermes = @import("hermes");
const Response = hermes.response.Response;
const Request = hermes.request.Request;
const Allocator = std.mem.Allocator;

pub const AthenaCore = struct {
    mutex: std.Thread.Mutex,
    base_dir: std.fs.Dir,

    alloc: Allocator,

    const Self = @This();

    fn handle_get_req(self: *Self, rq: Request) !Response {
        _ = rq;
        return Response.ok(self.alloc, "foo");
    }
    fn handle_put_req(self: *Self, rq: Request) !Response {
        _ = rq;
        return Response.ok(self.alloc, "foo");
    }
    fn handle_delete_req(self: *Self, rq: Request) !Response {
        _ = rq;
        return Response.ok(self.alloc, "foo");
    }
    fn handle_new_db_req(self: *Self, rq: Request) !Response {
        _ = rq;
        return Response.ok(self.alloc, "foo");
    }
    fn handle_new_coll_req(self: *Self, rq: Request) !Response {
        _ = rq;
        return Response.ok(self.alloc, "foo");
    }
    fn handle_delete_db_req(self: *Self, rq: Request) !Response {
        _ = rq;
        return Response.ok(self.alloc, "foo");
    }
    fn handle_delete_coll_req(self: *Self, rq: Request) !Response {
        _ = rq;
        return Response.ok(self.alloc, "foo");
    }
    fn handle_shutdown_req(self: *Self, rq: Request) !Response {
        _ = rq;
        return Response.ok(self.alloc, "foo");
    }

    pub fn handle_req(conn: std.net.Server.Connection, rq: Request, core: *AthenaCore) void {
        const rsp = switch (rq.header.method) {
            .Ping => Response.ok(core.alloc, "Pong") catch unreachable,
            .Get => core.handle_get_req(rq) catch unreachable,
            .Put => core.handle_put_req(rq) catch unreachable,
            .Delete => core.handle_delete_req(rq) catch unreachable,
            .NewDB => core.handle_new_db_req(rq) catch unreachable,
            .NewColl => core.handle_new_coll_req(rq) catch unreachable,
            .DeleteDB => core.handle_delete_db_req(rq) catch unreachable,
            .DeleteColl => core.handle_delete_coll_req(rq) catch unreachable,
            .Shutdown => core.handle_shutdown_req(rq) catch unreachable,
        };
        defer rsp.deinit();
        const s = rsp.serialize() catch unreachable;
        defer core.alloc.free(s);
        _ = conn.stream.writeAll(s) catch unreachable;
    }
};
