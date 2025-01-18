const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const DecodeError = error{
    UnexpectedPrefix,
};

pub const Field = union(Primitive) {
    Int: i32,
    Bool: bool,
    Float: f32,
    Char: u8,
    Arr: Array,

    pub const Array = struct {
        ///this field is not to be accessed directly, please use one of the provided functions
        arr: ArrayList(Field),
        alloc: Allocator,

        ///arrays can't contain arrays
        pub fn init(T: Field, alloc: Allocator, len: usize) !Array {
            std.debug.assert(@TypeOf(T) != @TypeOf(Array));
            const arr = try alloc.alloc(T, len);
            return Array{ .arr = arr, .len = len, .alloc = alloc };
        }

        pub fn deinit(self: *Array) void {
            self.alloc.free(self.arr);
        }

        fn encode_and_append(self: *const Array, w: anytype) !void {
            //if len is 0 we just send 0 as len and size with no items
            if (self.arr.items.len == 0) {
                try w.writeInt(u32, 0, .little);
                try w.writeInt(u32, 0, .little);
                return;
            }
            const i = try self.arr.items[0].encode(self.alloc);
            //write len of array
            try w.writeInt(u32, @intCast(self.arr.items.len), .little);
            //write size of each entry
            try w.writeInt(u32, @intCast(i.items.len), .little);
            for (self.arr.items) |v| {
                const bytes = try v.encode(self.alloc);
                //all items must have same size
                std.debug.assert(bytes.items.len == i.items.len);
            }
        }

        fn decode(alloc: Allocator, bytes: []u8) anyerror!struct { usize, Array } {
            var i: usize = 0;
            std.debug.assert(bytes[i] == 'A');
            i += 1;
            const size = std.mem.bytesToValue(u32, bytes[i..(i + 4)]);
            i += 4;
            const len = std.mem.bytesToValue(u32, bytes[i..(i + 4)]);
            i += 4;
            const total_size: usize = @as(usize, size * len);
            std.debug.assert(total_size + i <= bytes.len);
            var arr = try ArrayList(Field).initCapacity(alloc, len);
            for (0..len) |k| {
                //k is the index in the array, i the base offset so raw_ds are the bytes kth item in the array
                const raw_ds = bytes[(i + k * size)..(i + (k + 1) * size)];
                try arr.append(try Field.decode(raw_ds, alloc));
            }
            i += total_size;
            return .{ i, .{ .arr = arr, .alloc = alloc } };
        }
    };

    pub fn encode(self: *const Field, alloc: Allocator) anyerror!ArrayList(u8) {
        var bytes = ArrayList(u8).init(alloc);
        const w = bytes.writer();
        switch (self.*) {
            .Int => |*i| {
                try w.writeByte('I');
                try w.writeInt(i32, i.*, .little);
            },
            .Bool => |*b| {
                try w.writeByte('B');
                try w.writeByte(if (b.*) 1 else 0);
            },
            .Float => |*f| {
                try w.writeByte('F');
                try w.writeInt(u32, @bitCast(f.*), .little);
            },
            .Char => |*c| {
                try w.writeByte('C');
                try w.writeByte(c.*);
            },
            .Arr => |*a| {
                try w.writeByte('A');
                try a.encode_and_append(w);
            },
        }
        return bytes;
    }
    pub fn decode(bytes: []u8, alloc: Allocator) !Field {
        switch (bytes[0]) {
            'I' => |_| {
                const i = std.mem.bytesToValue(i32, bytes[1..4]);
                return Field{ .Int = i };
            },
            'B' => |_| {
                const b = (bytes[1] == 1);
                return Field{ .Bool = b };
            },
            'F' => |_| {
                const f = std.mem.bytesToValue(f32, bytes[1..4]);
                return Field{ .Float = f };
            },
            'C' => |_| {
                return Field{ .Char = bytes[1] };
            },
            'A' => |_| {
                const a = try Array.decode(alloc, bytes);
                return Field{ .Arr = a[1] };
            },
            else => |_| {
                return DecodeError.UnexpectedPrefix;
            },
        }
    }
};

pub const Primitive = enum {
    Int,
    Bool,
    Float,
    Char,
    Arr,
};

test "Field encode-decode" {
    const d = Field{ .Int = 32 };
    const alloc = std.testing.allocator;
    var tmp = try d.encode(alloc);
    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}
