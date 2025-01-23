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

    pub fn append_field(self: *Entry, f: Field) !void {
        try self.fields.append(f);
    }

    pub fn encode_append_writer(self: *const Entry, w: anytype) !void {
        try w.writeByte('E');

        for (self.fields.items) |*field| {
            try field.encode_append_writer(w);
        }
    }

    pub fn decode(raw: *Entry, bytes: []u8) !void {
        if (bytes[0] != 'E') {
            return EntryError.InvalidBytes;
        }
        var i: usize = 1;
        for (raw.fields.items) |*field| {
            i += try field.decode(bytes[i..]);
        }
    }
};

test "update field" {
    const alloc = std.testing.allocator;
    var e = Entry.init(alloc);
    defer e.deinit();
    try e.add_field(0, Field{ .Int = undefined });
    try e.update_field(0, Field{ .Int = 20 });
    try std.testing.expectEqual(Field{ .Int = 20 }, e.fields.items[0]);
}

test "entry encode-decode" {
    const Array = @import("hermes").field.Array;
    const alloc = std.testing.allocator;
    var e = Entry.init(alloc);
    defer e.deinit();

    try e.append_field(Field{ .Int = 10 });
    try e.append_field(Field{ .Bool = true });
    try e.append_field(Field{ .Float = std.math.pi });
    try e.append_field(Field{ .Char = 'H' });
    try e.append_field(Field{ .OID = 1 });

    var arr = try Array.init(.Int, alloc, 2);
    try arr.append(Field{ .Int = 1 });
    try arr.append(Field{ .Int = 2 });
    try e.append_field(Field{ .Arr = arr });

    var buf = ArrayList(u8).init(alloc);
    defer buf.deinit();
    const w = buf.writer();
    try e.encode_append_writer(w);

    var undef = Entry.init(alloc);
    defer undef.deinit();
    try undef.append_field(Field.undef_from_primitive(.Int, alloc));
    try undef.append_field(Field.undef_from_primitive(.Bool, alloc));
    try undef.append_field(Field.undef_from_primitive(.Float, alloc));
    try undef.append_field(Field.undef_from_primitive(.Char, alloc));
    try undef.append_field(Field.undef_from_primitive(.OID, alloc));
    try undef.append_field(Field.undef_from_primitive(.Arr, alloc));

    const bytes = try buf.toOwnedSlice();
    defer alloc.free(bytes);
    try undef.decode(bytes);

    try std.testing.expectEqualSlices(Field, e.fields.items[0..5], undef.fields.items[0..5]);

    const s = try e.fields.items[5].Arr.arr.toOwnedSlice();
    defer alloc.free(s);
    const u = try undef.fields.items[5].Arr.arr.toOwnedSlice();
    defer alloc.free(u);
    try std.testing.expectEqualSlices(Field, s, u);
}
