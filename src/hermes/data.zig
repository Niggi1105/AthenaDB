const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const DecodeError = error{
    UnexpectedPrefix,
};

pub const Array = struct {
    ///this field is not to be accessed directly, please use one of the provided functions
    T: Primitive,
    arr: ArrayList(Field),
    alloc: Allocator,
    len: usize,

    pub fn init(T: Primitive, alloc: Allocator, len: usize) !Array {
        std.debug.assert(T != Primitive.Arr);
        const arr = ArrayList(Field).init(alloc);
        return .{ .len = len, .T = T, .arr = arr, .alloc = alloc };
    }

    pub fn deinit(self: *Array) void {
        self.arr.deinit();
    }

    pub fn append(self: *Array, field: Field) !void {
        std.debug.assert(field.get_primitve() == self.T);
        std.debug.assert(self.len > self.arr.items.len);
        try self.arr.append(field);
    }

    fn encode_and_append(self: *const Array, w: anytype) !usize {
        //if len is 0 we just send 0 as len and size with no items
        if (self.arr.items.len == 0) {
            try w.writeInt(u8, 0, .little);
            try w.writeInt(u32, 0, .little);
            try w.writeInt(u32, 0, .little);
            return 9;
        }

        const i = self.T.enc_size();

        //1
        try w.writeByte(@intFromEnum(self.T));

        //write len of array
        //5
        try w.writeInt(u32, @intCast(self.arr.items.len), .little);

        //write size of each entry
        //9
        try w.writeInt(u32, @intCast(i), .little);

        for (self.arr.items) |v| {
            const n = try v.encode_append_writer(w);
            //all items must have same size
            std.debug.assert(n == i);
        }
        return 9 + i * self.arr.items.len;
    }

    fn decode(alloc: Allocator, bytes: []u8) anyerror!Array {
        var i: usize = 0;

        //the A indicates the beginning of the Array
        std.debug.assert(bytes[i] == 'A');
        i += 1;

        //the Primitive type
        const T: Primitive = @enumFromInt(bytes[1]);
        std.debug.assert(T != Primitive.Arr);
        i += 1;

        //the length of the array
        const len = std.mem.readInt(u32, bytes[2..6], .little);
        i += 4;

        //the size of each element
        const size = std.mem.readInt(u32, bytes[6..10], .little);
        i += 4;

        const total_size: usize = @as(usize, size * len);

        //the remaining bytes should be more or equal to the expected amount of bytes
        std.debug.assert(total_size + i <= bytes.len);

        var arr = try ArrayList(Field).initCapacity(alloc, len);

        for (0..len) |k| {
            //k is the index in the array, i the base offset so raw elements are the bytes kth item in the array
            const raw_elem = bytes[(i + k * size)..(i + (k + 1) * size)];
            const field = try Field.decode(raw_elem, alloc);
            std.debug.assert(field.get_primitve() == T);
            try arr.append(field);
        }
        i += total_size;
        return Array{ .len = len, .arr = arr, .alloc = alloc, .T = T };
    }
};

pub const Field = union(Primitive) {
    Int: i32,
    Bool: bool,
    Float: f32,
    Char: u8,
    Arr: Array,

    pub fn get_primitve(self: Field) Primitive {
        switch (self) {
            .Int => {
                return Primitive.Int;
            },
            .Bool => {
                return Primitive.Bool;
            },
            .Float => {
                return Primitive.Float;
            },
            .Char => {
                return Primitive.Char;
            },
            .Arr => {
                return Primitive.Arr;
            },
        }
    }

    pub fn encode_append_writer(self: *const Field, w: anytype) anyerror!usize {
        switch (self.*) {
            .Int => |*i| {
                try w.writeByte('I');
                try w.writeInt(i32, i.*, .little);
                return 5;
            },
            .Bool => |*b| {
                try w.writeByte('B');
                try w.writeByte(if (b.*) 255 else 0);
                return 2;
            },
            .Float => |*f| {
                try w.writeByte('F');
                try w.writeInt(u32, @bitCast(f.*), .little);
                return 5;
            },
            .Char => |*c| {
                try w.writeByte('C');
                try w.writeByte(c.*);
                return 2;
            },
            .Arr => |*a| {
                try w.writeByte('A');
                const n = try a.encode_and_append(w);
                return n + 1;
            },
        }
    }
    pub fn decode(bytes: []u8, alloc: Allocator) !Field {
        switch (bytes[0]) {
            'I' => |_| {
                const i = std.mem.bytesToValue(i32, bytes[1..5]);
                return Field{ .Int = i };
            },
            'B' => |_| {
                const b = (bytes[1] == 255);
                return Field{ .Bool = b };
            },
            'F' => |_| {
                const f = std.mem.bytesToValue(f32, bytes[1..5]);
                return Field{ .Float = f };
            },
            'C' => |_| {
                return Field{ .Char = bytes[1] };
            },
            'A' => |_| {
                const a = try Array.decode(alloc, bytes);
                return Field{ .Arr = a };
            },
            else => |_| {
                return DecodeError.UnexpectedPrefix;
            },
        }
    }
};

pub const Primitive = enum(u8) {
    Int = 0,
    Bool = 1,
    Float = 2,
    Char = 3,
    Arr = 4,

    pub fn enc_size(self: Primitive) usize {
        switch (self) {
            .Int => {
                return 5;
            },
            .Bool => {
                return 2;
            },
            .Float => {
                return 5;
            },
            .Char => {
                return 2;
            },
            .Arr => {
                return undefined;
            },
        }
    }
};

test "Int Field encode_append_writer-decode" {
    const d = Field{ .Int = 32 };
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    const n = try d.encode_append_writer(tmp.writer());
    try std.testing.expectEqual(5, n);

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}
test "Bool Field encode_append_writer-decode" {
    const d = Field{ .Bool = true };
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    const n = try d.encode_append_writer(tmp.writer());
    try std.testing.expectEqual(2, n);

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}
test "Float Field encode_append_writer-decode" {
    const d = Field{ .Float = 3.1415 };
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    const n = try d.encode_append_writer(tmp.writer());
    try std.testing.expectEqual(5, n);

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}
test "Char Field encode_append_writer-decode" {
    const d = Field{ .Char = 3 };
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    const n = try d.encode_append_writer(tmp.writer());
    try std.testing.expectEqual(2, n);

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}

test "Array init deinit" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.Int, alloc, 5);
    defer arr.deinit();

    try arr.append(Field{ .Int = 5 });
    try arr.append(Field{ .Int = 3 });
    try arr.append(Field{ .Int = 4 });
    try arr.append(Field{ .Int = 1 });
    try arr.append(Field{ .Int = 6 });

    const f = Field{ .Arr = arr };

    try std.testing.expectEqual(Primitive.Arr, f.get_primitve());

    var tmp = ArrayList(u8).init(alloc);
    defer tmp.deinit();
    const n = try f.encode_append_writer(tmp.writer());
    try std.testing.expectEqual(35, n);
}
