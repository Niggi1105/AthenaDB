const Response = @import("hermes").response.Response;
pub const Client = struct {
    pub fn get(filter: anytype) !Response {
        _ = filter;
    }
};
