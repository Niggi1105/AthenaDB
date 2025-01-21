const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Field = @import("hermes").field.Field;
const Primitive = @import("hermes").field.Primitive;

pub const Entry = struct {
    fields: ArrayList(Field),
};

test "get Field indices" {}
