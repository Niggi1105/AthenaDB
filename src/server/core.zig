const std = @import("std");
const hermes = @import("hermes");
const Response = hermes.response.Response;

pub const AthenaCore = struct {
    pub fn handle_req(conn: std.net.Server.Connection) void {
        _ = conn;
    }
};
