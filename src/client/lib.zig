const Response = @import("hermes").response.Response;
const std = @import("std");

pub const Client = struct {
    pub fn get(filter: anytype) !Response {
        _ = filter;
    }
};

test {
    std.testing.refAllDecls(@This());
}
