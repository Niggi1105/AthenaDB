const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Field = @import("hermes").field.Field;
const Primitive = @import("hermes").field.Primitive;
const Entry = @import("entry.zig").Entry;

pub const Table = struct {
    id: 128,
    entries: ArrayList(Entry),
    field_names: ArrayList([]u8),
    alloc: Allocator,

    fn index_of_field(self: *const Table, name: []u8) ?usize {
        for (0.., self.field_names) |i, f_name| {
            if (f_name == name) {
                return i;
            }
        }
        return null;
    }

    pub fn create(alloc: Allocator, id: u128) !Table {
        const entries = ArrayList(Field).init(alloc);
        const field_names = ArrayList([]u8).init(alloc);
        try field_names.append("_oid");

        return .{ .entries = entries, .id = id, .field_names = field_names, .alloc = alloc };
    }
};
