const std = @import("std");
const hermes = @import("hermes");
const Response = hermes.response.Response;
const Request = hermes.request.Request;
const Allocator = std.mem.Allocator;

pub const AthenaCore = struct {
    pub fn handle_req(alloc: Allocator, conn: std.net.Server.Connection, rq: Request) void {
        switch (rq.header.method) {
            .Ping => {
                const rsp = Response.ok(alloc, "Pong") catch unreachable;
                defer rsp.deinit();
                const s = rsp.serialize() catch unreachable;
                defer alloc.free(s);
                _ = conn.stream.writeAll(s) catch unreachable;
            },
            .Get => {},
            .Put => {},
            .Delete => {},
            .NewDB => {},
            .NewColl => {},
            .DeleteDB => {},
            .DeleteColl => {},
            .Shutdown => {},
        }
    }
};
