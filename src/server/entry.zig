const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Field = @import("hermes").field.Field;
const Primitive = @import("hermes").field.Primitive;
const ServerError = @import("core.zig").ServerError;

pub const EntryError = error{
    TypeMismatch,
    FieldAtIndexNotInitialized,
    IndexOutOfBounds,
    InvalidBytes,
};

pub const Entry = struct {
    fields: ArrayList(Field),

    pub fn init(alloc: Allocator) Entry {
        return .{ .fields = ArrayList(Field).init(alloc) };
    }
    pub fn init_with_oid(alloc: Allocator, id: u64) !Entry {
        var entry = .{ .fields = ArrayList(Field).init(alloc) };
        try entry.add_field(0, Field{ .OID = id });

        return entry;
    }

    pub fn deinit(self: Entry) void {
        for (self.fields.items) |field| {
            field.deinit();
        }
        self.fields.deinit();
    }
    pub fn get_field(self: *const Entry, i: usize) !*const Field {
        if (i >= self.fields.items.len) {
            return EntryError.IndexOutOfBounds;
        }
        return &self.fields.items[i];
    }
    pub fn get_field_mut(self: *Entry, i: usize) !*Field {
        if (i >= self.fields.items.len) {
            return EntryError.IndexOutOfBounds;
        }
        return &self.fields.items[i];
    }

    pub fn update_field(self: *Entry, i: usize, update: Field) !void {
        var f = try self.get_field_mut(i);
        if (f.get_primitve() != update.get_primitve()) {
            return EntryError.TypeMismatch;
        }
        f.* = update;
    }

    pub fn add_field(self: *Entry, i: usize, f: Field) !void {
        if (i > self.fields.items.len) {
            return EntryError.IndexOutOfBounds;
        }
        self.fields.insert(i, f) catch return ServerError.OutOfMemory;
    }

    pub fn encode_append_writer(self: *const Entry, w: anytype) !void {
        try w.writeByte('E');

        for (self.fields.items) |*field| {
            try field.encode_append_writer(w);
        }
    }

    //TODO mke it so we can put in an array list with fields with undefined values and then just fill in the fields
    pub fn decode(alloc: Allocator, bytes: []u8) !void {
        var arr = ArrayList(Field).init(alloc);

        if (bytes[0] != 'E') {
            return EntryError.InvalidBytes;
        }
        for (self.fields.items) |*field| {
            arr.append(try Field.decode(bytes[1..], alloc));
        }
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
