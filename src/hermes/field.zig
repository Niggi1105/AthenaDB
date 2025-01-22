const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const DecodeError = error{
    UnexpectedPrefix,
};

pub const ArrayError = error{
    MaxSize,
};

pub const Array = struct {
    ///this field is not to be accessed directly, please use one of the provided functions
    T: Primitive,
    arr: ArrayList(Field),
    alloc: Allocator,
    len: usize,

    pub fn init(T: Primitive, alloc: Allocator, len: usize) !Array {
        std.debug.assert(T != Primitive.Arr);
        const arr = try ArrayList(Field).initCapacity(alloc, len);
        return .{ .len = len, .T = T, .arr = arr, .alloc = alloc };
    }

    pub fn deinit(self: *Array) void {
        self.arr.deinit();
    }

    pub fn append(self: *Array, field: Field) !void {
        std.debug.assert(field.get_primitve() == self.T);
        if (self.len <= self.arr.items.len) {
            return ArrayError.MaxSize;
        }
        try self.arr.append(field);
    }

    fn encode_and_append(self: *const Array, w: anytype) !void {
        //if len is 0 we just send 0 as len and size with no items
        if (self.arr.items.len == 0) {
            try w.writeInt(u8, 0, .little);
            try w.writeInt(u32, 0, .little);
            try w.writeInt(u32, 0, .little);
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
            std.debug.assert(v.get_primitve() == self.T);
            try v.encode_append_writer(w);
        }
    }

    fn decode(alloc: Allocator, bytes: []u8) anyerror!Array {

        //the A indicates the beginning of the Array
        std.debug.assert(bytes[0] == 'A');

        //the Primitive type
        const T: Primitive = @enumFromInt(bytes[1]);
        std.debug.assert(T != Primitive.Arr);

        //the length of the array
        const len = std.mem.readInt(u32, bytes[2..6], .little);

        //the size of each element
        const size = std.mem.readInt(u32, bytes[6..10], .little);

        const total_size: usize = @as(usize, size * len);

        //the remaining bytes should be more or equal to the expected amount of bytes
        std.debug.assert(total_size + 10 <= bytes.len);

        var arr = try ArrayList(Field).initCapacity(alloc, len);

        for (0..len) |k| {
            //k is the index in the array, 10 the base offset so raw elements are the bytes kth item in the array
            const raw_elem = bytes[(10 + k * size)..(10 + (k + 1) * size)];
            const field = try Field.decode(raw_elem, alloc);
            std.debug.assert(field.get_primitve() == T);
            try arr.append(field);
        }
        return Array{ .len = len, .arr = arr, .alloc = alloc, .T = T };
    }
};

//TODO: make it so that the decode takes a Field with undefined value, but defined enum variant as parameter, this allows for more efficient and safe decoding
pub const Field = union(Primitive) {
    Int: i32,
    Bool: bool,
    Float: f32,
    Char: u8,
    Arr: Array,
    OID: u64,

    pub fn deinit(self: Field) void {
        switch (self) {
            .Arr => |arr| arr.deinit(),
            else => {},
        }
    }

    pub fn get_primitve(self: *const Field) Primitive {
        switch (self.*) {
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
            .OID => {
                return Primitive.OID;
            },
        }
    }

    pub fn encode_append_writer(self: *const Field, w: anytype) anyerror!void {
        switch (self.*) {
            .Int => |*i| {
                try w.writeByte('I');
                try w.writeInt(i32, i.*, .little);
            },
            .Bool => |*b| {
                try w.writeByte('B');
                try w.writeByte(if (b.*) 255 else 0);
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
            .OID => |*o| {
                try w.writeByte('O');
                try w.writeInt(u64, o.*, .little);
            },
        }
    }
    pub fn decode(bytes: []u8, alloc: Allocator) !Field {
        switch (bytes[0]) {
            'I' => |_| {
                const i = std.mem.readInt(i32, bytes[1..5], .little);
                return Field{ .Int = i };
            },
            'O' => |_| {
                const i = std.mem.readInt(u64, bytes[1..9], .little);
                return Field{ .OID = i };
            },
            'B' => |_| {
                const b = (bytes[1] == 255);
                return Field{ .Bool = b };
            },
            'F' => |_| {
                const r = std.mem.readInt(u32, bytes[1..5], .little);
                const f: f32 = @bitCast(r);
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
    OID = 5,

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
            .OID => {
                return 9;
            },
            .Arr => {
                return undefined;
            },
        }
    }
};

test "Int Field encode-decode" {
    const d = Field{ .Int = 32 };
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    try d.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}
test "Bool Field encode-decode" {
    const d = Field{ .Bool = true };
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    try d.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}
test "Float Field encode-decode" {
    const d = Field{ .Float = 3.1415 };
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    try d.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}
test "Char Field encode-decode" {
    const d = Field{ .Char = 3 };
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    try d.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}
test "OID Field encode-decode" {
    const d = Field{ .OID = std.math.maxInt(u64) };
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    try d.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);
    const dec = try Field.decode(enc, alloc);

    try std.testing.expectEqual(d, dec);
}

test "int array encode decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.Int, alloc, 5);

    try arr.append(Field{ .Int = 5 });
    try arr.append(Field{ .Int = 3 });
    try arr.append(Field{ .Int = 4 });
    try arr.append(Field{ .Int = 1 });
    try arr.append(Field{ .Int = 6 });

    const f = Field{ .Arr = arr };

    try std.testing.expectEqual(Primitive.Arr, f.get_primitve());

    var tmp = ArrayList(u8).init(alloc);
    try f.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);

    var dec = try Field.decode(enc, alloc);
    try std.testing.expectEqual(dec.get_primitve(), Primitive.Arr);

    const d = try dec.Arr.arr.toOwnedSlice();
    defer alloc.free(d);

    const e = try arr.arr.toOwnedSlice();
    defer alloc.free(e);

    try std.testing.expectEqualSlices(Field, e, d);
}

test "float array encode decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.Float, alloc, 5);

    try arr.append(Field{ .Float = std.math.e });
    try arr.append(Field{ .Float = std.math.pi });
    try arr.append(Field{ .Float = 0.0 });
    try arr.append(Field{ .Float = 1.0 });
    try arr.append(Field{ .Float = -1.0 });

    const f = Field{ .Arr = arr };

    try std.testing.expectEqual(Primitive.Arr, f.get_primitve());

    var tmp = ArrayList(u8).init(alloc);
    try f.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);

    var dec = try Field.decode(enc, alloc);
    try std.testing.expectEqual(dec.get_primitve(), Primitive.Arr);

    const d = try dec.Arr.arr.toOwnedSlice();
    defer alloc.free(d);

    const e = try arr.arr.toOwnedSlice();
    defer alloc.free(e);

    try std.testing.expectEqualSlices(Field, e, d);
}

test "bool array encode decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.Bool, alloc, 5);

    try arr.append(Field{ .Bool = true });
    try arr.append(Field{ .Bool = false });
    try arr.append(Field{ .Bool = true });
    try arr.append(Field{ .Bool = false });
    try arr.append(Field{ .Bool = false });

    const f = Field{ .Arr = arr };

    try std.testing.expectEqual(Primitive.Arr, f.get_primitve());

    var tmp = ArrayList(u8).init(alloc);
    try f.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);

    var dec = try Field.decode(enc, alloc);
    try std.testing.expectEqual(dec.get_primitve(), Primitive.Arr);

    const d = try dec.Arr.arr.toOwnedSlice();
    defer alloc.free(d);

    const e = try arr.arr.toOwnedSlice();
    defer alloc.free(e);

    try std.testing.expectEqualSlices(Field, e, d);
}
test "char array encode decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.Char, alloc, 5);

    try arr.append(Field{ .Char = 'H' });
    try arr.append(Field{ .Char = 'e' });
    try arr.append(Field{ .Char = 'l' });
    try arr.append(Field{ .Char = 'l' });
    try arr.append(Field{ .Char = 'o' });

    const f = Field{ .Arr = arr };

    try std.testing.expectEqual(Primitive.Arr, f.get_primitve());

    var tmp = ArrayList(u8).init(alloc);
    try f.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);

    var dec = try Field.decode(enc, alloc);
    try std.testing.expectEqual(dec.get_primitve(), Primitive.Arr);

    const d = try dec.Arr.arr.toOwnedSlice();
    defer alloc.free(d);

    const e = try arr.arr.toOwnedSlice();
    defer alloc.free(e);

    try std.testing.expectEqualSlices(Field, e, d);
}
test "OID array encode decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.OID, alloc, 5);

    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });

    const f = Field{ .Arr = arr };

    try std.testing.expectEqual(Primitive.Arr, f.get_primitve());

    var tmp = ArrayList(u8).init(alloc);
    try f.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);

    var dec = try Field.decode(enc, alloc);
    try std.testing.expectEqual(dec.get_primitve(), Primitive.Arr);

    const d = try dec.Arr.arr.toOwnedSlice();
    defer alloc.free(d);

    const e = try arr.arr.toOwnedSlice();
    defer alloc.free(e);

    try std.testing.expectEqualSlices(Field, e, d);
}
test "array to many items" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.OID, alloc, 5);

    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try std.testing.expectError(ArrayError.MaxSize, arr.append(Field{ .OID = std.math.maxInt(u64) }));

    const f = Field{ .Arr = arr };

    try std.testing.expectEqual(Primitive.Arr, f.get_primitve());

    var tmp = ArrayList(u8).init(alloc);
    try f.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);

    var dec = try Field.decode(enc, alloc);
    try std.testing.expectEqual(dec.get_primitve(), Primitive.Arr);

    const d = try dec.Arr.arr.toOwnedSlice();
    defer alloc.free(d);

    const e = try arr.arr.toOwnedSlice();
    defer alloc.free(e);

    try std.testing.expectEqualSlices(Field, e, d);
}

test "array to few items" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.OID, alloc, 5);

    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });
    try arr.append(Field{ .OID = std.math.maxInt(u64) });

    const f = Field{ .Arr = arr };

    try std.testing.expectEqual(Primitive.Arr, f.get_primitve());

    var tmp = ArrayList(u8).init(alloc);
    try f.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);

    var dec = try Field.decode(enc, alloc);
    try std.testing.expectEqual(dec.get_primitve(), Primitive.Arr);

    const d = try dec.Arr.arr.toOwnedSlice();
    defer alloc.free(d);

    const e = try arr.arr.toOwnedSlice();
    defer alloc.free(e);

    try std.testing.expectEqualSlices(Field, e, d);
}
