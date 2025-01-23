const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Record = @import("hermes").record.Record;
const Primitive = @import("hermes").record.Primitive;
const ServerError = @import("core.zig").ServerError;

pub const EntryError = error{
    TypeMismatch,
    FieldAtIndexNotInitialized,
    IndexOutOfBounds,
    InvalidBytes,
};

pub const Entry = struct {
    fields: ArrayList(Record),

    pub fn init(alloc: Allocator) Entry {
        return .{ .fields = ArrayList(Record).init(alloc) };
    }
    pub fn init_with_oid(alloc: Allocator, id: u64) !Entry {
        var entry = .{ .fields = ArrayList(Record).init(alloc) };
        try entry.add_field(0, Record{ .OID = id });

        return entry;
    }

    pub fn deinit(self: Entry) void {
        for (self.fields.items) |record| {
            record.deinit();
        }
        self.fields.deinit();
    }

    pub fn get_field(self: *const Entry, i: usize) !*const Record {
        if (i >= self.fields.items.len) {
            return EntryError.IndexOutOfBounds;
        }
        return &self.fields.items[i];
    }

    pub fn get_field_mut(self: *Entry, i: usize) !*Record {
        if (i >= self.fields.items.len) {
            return EntryError.IndexOutOfBounds;
        }
        return &self.fields.items[i];
    }

    pub fn update_field(self: *Entry, i: usize, update: Record) !void {
        var f = try self.get_field_mut(i);
        if (f.get_primitve() != update.get_primitve()) {
            return EntryError.TypeMismatch;
        }
        f.* = update;
    }

    pub fn add_field(self: *Entry, i: usize, f: Record) !void {
        if (i > self.fields.items.len) {
            return EntryError.IndexOutOfBounds;
        }
        self.fields.insert(i, f) catch return ServerError.OutOfMemory;
    }

    pub fn append_field(self: *Entry, f: Record) !void {
        try self.fields.append(f);
    }

    pub fn encode_append_writer(self: *const Entry, w: anytype) !void {
        try w.writeByte('E');

        for (self.fields.items) |*record| {
            try record.encode_append_writer(w);
        }
    }

    pub fn decode(raw: *Entry, bytes: []u8) !usize {
        if (bytes[0] != 'E') {
            return EntryError.InvalidBytes;
        }
        var i: usize = 1;
        for (raw.fields.items) |*record| {
            i += try record.decode(bytes[i..]);
        }
        return i;
    }
};

test "basic functunality" {
    const alloc = std.testing.allocator;
    var e = Entry.init(alloc);
    defer e.deinit();
    try e.add_field(0, Record{ .Int = undefined });
    try e.update_field(0, Record{ .Int = 20 });
    try std.testing.expectError(EntryError.TypeMismatch, e.update_field(0, Record{ .Bool = true }));
    try std.testing.expectError(EntryError.IndexOutOfBounds, e.add_field(2, Record{ .Bool = true }));
    try std.testing.expectEqual(Record{ .Int = 20 }, e.fields.items[0]);
}

test "entry encode-decode" {
    const Array = @import("hermes").record.Array;
    const alloc = std.testing.allocator;
    var e = Entry.init(alloc);
    defer e.deinit();

    try e.append_field(Record{ .Int = 10 });
    try e.append_field(Record{ .Bool = true });
    try e.append_field(Record{ .Float = std.math.pi });
    try e.append_field(Record{ .Char = 'H' });
    try e.append_field(Record{ .OID = 1 });

    var arr = try Array.init(.Int, alloc, 2);
    try arr.append(Record{ .Int = 1 });
    try arr.append(Record{ .Int = 2 });
    try e.append_field(Record{ .Arr = arr });

    var buf = ArrayList(u8).init(alloc);
    defer buf.deinit();
    const w = buf.writer();
    try e.encode_append_writer(w);

    var undef = Entry.init(alloc);
    defer undef.deinit();
    try undef.append_field(Record.undef_from_primitive(.Int, alloc));
    try undef.append_field(Record.undef_from_primitive(.Bool, alloc));
    try undef.append_field(Record.undef_from_primitive(.Float, alloc));
    try undef.append_field(Record.undef_from_primitive(.Char, alloc));
    try undef.append_field(Record.undef_from_primitive(.OID, alloc));
    try undef.append_field(Record.undef_from_primitive(.Arr, alloc));

    const bytes = try buf.toOwnedSlice();
    defer alloc.free(bytes);
    _ = try undef.decode(bytes);

    try std.testing.expectEqualSlices(Record, e.fields.items[0..5], undef.fields.items[0..5]);

    const s = try e.fields.items[5].Arr.arr.toOwnedSlice();
    defer alloc.free(s);
    const u = try undef.fields.items[5].Arr.arr.toOwnedSlice();
    defer alloc.free(u);
    try std.testing.expectEqualSlices(Record, s, u);
}
