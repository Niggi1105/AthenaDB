const std = @import("std");

pub const Response = struct {
    status: u8,
    len: usize,
    data: []u8,
};
