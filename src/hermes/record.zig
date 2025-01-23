const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const FieldError = error{
    TypeMismatch,
};
pub const DecodeError = error{
    InvalidBytes,
    RecursiveType,
    TypeMismatch,
};

pub const ArrayError = error{
    MaxSize,
    TypeMismatch,
    NotAllowed,
};

pub const Array = struct {
    ///this field is not to be accessed directly, please use one of the provided functions
    T: Primitive,
    arr: ArrayList(Record),
    alloc: Allocator,
    len: usize,

    pub fn init(T: Primitive, alloc: Allocator, len: usize) !Array {
        if (T == Primitive.Arr) {
            return ArrayError.NotAllowed;
        }
        const arr = try ArrayList(Record).initCapacity(alloc, len);
        return .{ .len = len, .T = T, .arr = arr, .alloc = alloc };
    }

    pub fn deinit(self: Array) void {
        self.arr.deinit();
    }

    ///creates an Array of undefined type and length
    pub fn init_undef(alloc: Allocator) Array {
        return .{ .len = undefined, .T = undefined, .alloc = alloc, .arr = ArrayList(Record).init(alloc) };
    }

    pub fn append(self: *Array, field: Record) !void {
        if (field.get_primitve() != self.T) {
            return ArrayError.TypeMismatch;
        }

        if (self.len <= self.arr.items.len) {
            return ArrayError.MaxSize;
        }
        try self.arr.append(field);
    }

    ///asserts that every item has the same Primitive type
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

    //the passed array should be completely undefined except for an initialized array list and an allocator
    fn decode(arr: *Array, bytes: []u8) anyerror!usize {
        //the Primitive type of the items
        const T: Primitive = @enumFromInt(bytes[0]);
        if (T == Primitive.Arr) {
            return DecodeError.RecursiveType;
        }
        arr.T = T;

        //the length of the array
        const len = std.mem.readInt(u32, bytes[1..5], .little);
        arr.len = len;

        //the size of each element
        const size = std.mem.readInt(u32, bytes[5..9], .little);
        //we assert that the size matches that of our expected type
        if (size != T.enc_size()) {
            return DecodeError.InvalidBytes;
        }

        const total_size: usize = @as(usize, size * len);

        //the remaining bytes should be more or equal to the expected amount of bytes
        if (total_size + 9 > bytes.len) {
            return DecodeError.InvalidBytes;
        }

        for (0..len) |k| {
            //k is the index in the array, 9 is the base offset so raw elements are the bytes kth item in the array
            var raw = Record.undef_from_primitive(T, arr.alloc);
            const raw_bytes = bytes[(9 + k * size)..(9 + (k + 1) * size)];
            _ = try raw.decode(raw_bytes);
            try arr.append(raw);
        }

        //9 bytes header, plus 1 byte Prefix
        return total_size + 9 + 1;
    }
};

pub const Record = union(Primitive) {
    Int: i32,
    Bool: bool,
    Float: f32,
    Char: u8,
    Arr: Array,
    OID: u64,

    pub fn deinit(self: Record) void {
        switch (self) {
            .Arr => |arr| arr.deinit(),
            else => {},
        }
    }

    pub fn get_primitve(self: *const Record) Primitive {
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

    pub fn undef_from_primitive(T: Primitive, alloc: Allocator) Record {
        switch (T) {
            .Int => return Record{ .Int = undefined },
            .Bool => return Record{ .Bool = undefined },
            .Float => return Record{ .Float = undefined },
            .Char => return Record{ .Char = undefined },
            .Arr => return Record{ .Arr = Array.init_undef(alloc) },
            .OID => return Record{ .OID = undefined },
        }
    }

    pub fn encode_append_writer(self: *const Record, w: anytype) anyerror!void {
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
    pub fn decode(field: *Record, bytes: []u8) !usize {
        switch (bytes[0]) {
            'I' => |_| {
                if (field.get_primitve() != .Int) {
                    return DecodeError.TypeMismatch;
                }
                const i = std.mem.readInt(i32, bytes[1..5], .little);
                field.Int = i;
                return Primitive.Int.enc_size();
            },
            'O' => |_| {
                if (field.get_primitve() != .OID) {
                    return DecodeError.TypeMismatch;
                }
                const o = std.mem.readInt(u64, bytes[1..9], .little);
                field.OID = o;
                return Primitive.OID.enc_size();
            },
            'B' => |_| {
                if (field.get_primitve() != .Bool) {
                    return DecodeError.TypeMismatch;
                }
                const b = (bytes[1] == 255);
                field.Bool = b;
                return Primitive.Bool.enc_size();
            },
            'F' => |_| {
                if (field.get_primitve() != .Float) {
                    return DecodeError.TypeMismatch;
                }
                const r = std.mem.readInt(u32, bytes[1..5], .little);
                const f: f32 = @bitCast(r);
                field.Float = f;
                return Primitive.Float.enc_size();
            },
            'C' => |_| {
                if (field.get_primitve() != .Char) {
                    return DecodeError.TypeMismatch;
                }
                field.Char = bytes[1];
                return Primitive.Char.enc_size();
            },
            'A' => |_| {
                if (field.get_primitve() != .Arr) {
                    return DecodeError.TypeMismatch;
                }
                return try field.Arr.decode(bytes[1..]);
            },
            else => |_| {
                return DecodeError.InvalidBytes;
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

///this fn is purely for testing purposes
fn test_primitives(d: Record) !void {
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    try d.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);

    var f = Record.undef_from_primitive(d.get_primitve(), alloc);

    try std.testing.expectEqual(d.get_primitve().enc_size(), try f.decode(enc));

    try std.testing.expectEqual(d, f);
}

fn test_arr(d: *Record) !void {
    const alloc = std.testing.allocator;

    var tmp = ArrayList(u8).init(alloc);
    try d.encode_append_writer(tmp.writer());

    const enc = try tmp.toOwnedSlice();
    defer alloc.free(enc);

    var f = Record.undef_from_primitive(d.get_primitve(), alloc);
    try std.testing.expectEqual(d.Arr.T.enc_size() * d.Arr.arr.items.len + 10, try f.decode(enc));

    const e = try d.Arr.arr.toOwnedSlice();
    defer alloc.free(e);

    const fb = try f.Arr.arr.toOwnedSlice();
    defer alloc.free(fb);

    try std.testing.expectEqualSlices(Record, e, fb);
}

test "Int Record encode-decode" {
    try test_primitives(Record{ .Int = 32 });
}
test "Bool Record encode-decode" {
    try test_primitives(Record{ .Bool = true });
}
test "Float Record encode-decode" {
    try test_primitives(Record{ .Float = std.math.pi });
}
test "Char Record encode-decode" {
    try test_primitives(Record{ .Char = 'A' });
}
test "OID Record encode-decode" {
    try test_primitives(Record{ .OID = std.math.maxInt(u64) });
}

test "basic array functionality" {
    const alloc = std.testing.allocator;
    try std.testing.expectError(ArrayError.NotAllowed, Array.init(Primitive.Arr, alloc, 10));
    var arr = try Array.init(.Int, alloc, 5);
    defer arr.deinit();
    try std.testing.expectError(ArrayError.TypeMismatch, arr.append(Record{ .Bool = true }));
    try arr.append(Record{ .Int = 10 });
    try arr.append(Record{ .Int = 2 });
    try arr.append(Record{ .Int = -30 });
    try arr.append(Record{ .Int = 5 });
    try arr.append(Record{ .Int = 4000 });
    try std.testing.expectError(ArrayError.MaxSize, arr.append(Record{ .Int = 3 }));
}
test "int array encode-decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.Int, alloc, 5);

    try arr.append(Record{ .Int = 10 });
    try arr.append(Record{ .Int = 2 });
    try arr.append(Record{ .Int = -30 });
    try arr.append(Record{ .Int = 5 });
    try arr.append(Record{ .Int = 4000 });

    var f = Record{ .Arr = arr };
    try test_arr(&f);
}

test "bool array encode-decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.Bool, alloc, 5);

    try arr.append(Record{ .Bool = true });
    try arr.append(Record{ .Bool = true });
    try arr.append(Record{ .Bool = false });
    try arr.append(Record{ .Bool = true });
    try arr.append(Record{ .Bool = false });

    var f = Record{ .Arr = arr };
    try test_arr(&f);
}

test "float array encode-decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.Float, alloc, 5);

    try arr.append(Record{ .Float = 4.0 });
    try arr.append(Record{ .Float = -134.0 });
    try arr.append(Record{ .Float = std.math.pi });
    try arr.append(Record{ .Float = std.math.e });
    try arr.append(Record{ .Float = @sqrt(2.0) });

    var f = Record{ .Arr = arr };
    try test_arr(&f);
}
test "char array encode-decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.Char, alloc, 5);

    try arr.append(Record{ .Char = 'H' });
    try arr.append(Record{ .Char = 'E' });
    try arr.append(Record{ .Char = 'L' });
    try arr.append(Record{ .Char = 'L' });
    try arr.append(Record{ .Char = 'O' });

    var f = Record{ .Arr = arr };
    try test_arr(&f);
}

test "oid array encode-decode" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.OID, alloc, 5);

    try arr.append(Record{ .OID = std.math.maxInt(u64) });
    try arr.append(Record{ .OID = std.math.maxInt(u64) });
    try arr.append(Record{ .OID = std.math.maxInt(u64) });
    try arr.append(Record{ .OID = std.math.maxInt(u64) });
    try arr.append(Record{ .OID = std.math.maxInt(u64) });

    var f = Record{ .Arr = arr };
    try test_arr(&f);
}

test "array encode-decode, less than max items" {
    const alloc = std.testing.allocator;

    var arr = try Array.init(.OID, alloc, 5);

    try arr.append(Record{ .OID = std.math.maxInt(u64) });
    try arr.append(Record{ .OID = std.math.maxInt(u64) });
    try arr.append(Record{ .OID = std.math.maxInt(u64) });

    var f = Record{ .Arr = arr };
    try test_arr(&f);
}
