const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Field = @import("hermes").field.Field;
const Primitive = @import("hermes").field.Primitive;

pub const EntryError = error{
    TypeMismatch,
    FieldAtIndexNotInitialized,
    IndexOutOfBounds,
};

pub const Entry = struct {
    fields: ArrayList(Field),

    pub fn init(alloc: Allocator) Entry {
        return .{ .fields = ArrayList(Field).init(alloc) };
    }
    pub fn deinit(self: Entry) void {
        self.fields.deinit();
    }
    pub fn get_field(self: *const Entry, i: usize) *const Field {
        return &self.fields.items[i];
    }
    pub fn get_field_mut(self: *Entry, i: usize) *Field {
        return &self.fields.items[i];
    }

    pub fn update_field(self: *Entry, i: usize, update: Field) !void {
        var f = self.get_field_mut(i);
        if (f.get_primitve() != update.get_primitve()) {
            return EntryError.TypeMismatch;
        }
        f.* = update;
    }

    pub fn add_field(self: *Entry, i: usize, f: Field) !void {
        if (i > self.fields.items.len) {
            return EntryError.IndexOutOfBounds;
        }
        try self.fields.insert(i, f);
    }
};

test "update field" {
    const alloc = std.testing.allocator;
    var e = Entry.init(alloc);
    defer e.deinit();
    try e.add_field(0, Field{ .Int = undefined });
    try e.update_field(0, Field{ .Int = 20 });
    try std.testing.expectEqual(Field{ .Int = 20 }, e.get_field(0).*);
}
