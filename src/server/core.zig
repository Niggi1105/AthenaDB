const std = @import("std");
const hermes = @import("hermes");
const Response = hermes.response.Response;
const Allocator = std.mem.Allocator;

pub const AthenaCore = struct {
    pub fn handle_req(alloc: Allocator, conn: std.net.Server.Connection) void {
        const rsp = Response.ok(alloc, "Pong") catch unreachable;
        defer rsp.deinit();
        const s = rsp.serialize() catch unreachable;
        defer alloc.free(s);
        _ = conn.stream.writeAll(s) catch unreachable;
    }
};
