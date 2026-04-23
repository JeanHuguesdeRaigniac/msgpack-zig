const std = @import("std");
const types = @import("types.zig");
const Tag = types.Tag;

pub const EncodeError = error{
    BufferTooSmall,
    StringTooLong,
    BinaryTooLong,
    ContainerTooLarge,
};

pub const Encoder = struct {
    buf: []u8,
    pos: usize,

    pub fn init(buf: []u8) Encoder {
        return .{ .buf = buf, .pos = 0 };
    }

    pub fn written(self: *const Encoder) []const u8 {
        return self.buf[0..self.pos];
    }

    fn write1(self: *Encoder, b: u8) EncodeError!void {
        if (self.pos >= self.buf.len) return error.BufferTooSmall;
        self.buf[self.pos] = b;
        self.pos += 1;
    }

    fn writeN(self: *Encoder, bytes: []const u8) EncodeError!void {
        if (self.pos + bytes.len > self.buf.len) return error.BufferTooSmall;
        @memcpy(self.buf[self.pos..][0..bytes.len], bytes);
        self.pos += bytes.len;
    }

    pub fn writeNil(self: *Encoder) EncodeError!void {
        try self.write1(Tag.nil);
    }

    pub fn writeBool(self: *Encoder, value: bool) EncodeError!void {
        try self.write1(if (value) Tag.@"true" else Tag.@"false");
    }

    pub fn writeInt(self: *Encoder, value: i64) EncodeError!void {
        if (value >= 0) {
            const u: u64 = @intCast(value);
            if (u <= 0x7f) {
                try self.write1(@intCast(u));
            } else if (u <= 0xff) {
                try self.write1(Tag.uint8);
                try self.write1(@intCast(u));
            } else if (u <= 0xffff) {
                try self.write1(Tag.uint16);
                try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u16, @intCast(u))));
            } else if (u <= 0xffffffff) {
                try self.write1(Tag.uint32);
                try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u32, @intCast(u))));
            } else {
                try self.write1(Tag.uint64);
                try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u64, u)));
            }
        } else {
            if (value >= -32) {
                try self.write1(@bitCast(@as(i8, @intCast(value))));
            } else if (value >= -128) {
                try self.write1(Tag.int8);
                try self.write1(@bitCast(@as(i8, @intCast(value))));
            } else if (value >= -32768) {
                try self.write1(Tag.int16);
                try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(i16, @intCast(value))));
            } else if (value >= -2147483648) {
                try self.write1(Tag.int32);
                try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(i32, @intCast(value))));
            } else {
                try self.write1(Tag.int64);
                try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(i64, value)));
            }
        }
    }

    pub fn writeUint(self: *Encoder, value: u64) EncodeError!void {
        if (value <= std.math.maxInt(i64)) {
            try self.writeInt(@intCast(value));
        } else {
            try self.write1(Tag.uint64);
            try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u64, value)));
        }
    }

    pub fn writeFloat32(self: *Encoder, value: f32) EncodeError!void {
        try self.write1(Tag.float32);
        try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u32, @bitCast(value))));
    }

    pub fn writeFloat64(self: *Encoder, value: f64) EncodeError!void {
        try self.write1(Tag.float64);
        try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u64, @bitCast(value))));
    }

    pub fn writeStr(self: *Encoder, value: []const u8) EncodeError!void {
        const len = value.len;
        if (len <= 31) {
            try self.write1(Tag.fixstr_base | @as(u8, @intCast(len)));
        } else if (len <= 0xff) {
            try self.write1(Tag.str8);
            try self.write1(@intCast(len));
        } else if (len <= 0xffff) {
            try self.write1(Tag.str16);
            try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u16, @intCast(len))));
        } else if (len <= 0xffffffff) {
            try self.write1(Tag.str32);
            try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u32, @intCast(len))));
        } else {
            return error.StringTooLong;
        }
        try self.writeN(value);
    }

    pub fn writeBin(self: *Encoder, value: []const u8) EncodeError!void {
        const len = value.len;
        if (len <= 0xff) {
            try self.write1(Tag.bin8);
            try self.write1(@intCast(len));
        } else if (len <= 0xffff) {
            try self.write1(Tag.bin16);
            try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u16, @intCast(len))));
        } else if (len <= 0xffffffff) {
            try self.write1(Tag.bin32);
            try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u32, @intCast(len))));
        } else {
            return error.BinaryTooLong;
        }
        try self.writeN(value);
    }

    pub fn writeArrayHeader(self: *Encoder, len: u32) EncodeError!void {
        if (len <= 15) {
            try self.write1(Tag.fixarray_base | @as(u8, @intCast(len)));
        } else if (len <= 0xffff) {
            try self.write1(Tag.array16);
            try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u16, @intCast(len))));
        } else {
            try self.write1(Tag.array32);
            try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u32, len)));
        }
    }

    pub fn writeMapHeader(self: *Encoder, len: u32) EncodeError!void {
        if (len <= 15) {
            try self.write1(Tag.fixmap_base | @as(u8, @intCast(len)));
        } else if (len <= 0xffff) {
            try self.write1(Tag.map16);
            try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u16, @intCast(len))));
        } else {
            try self.write1(Tag.map32);
            try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u32, len)));
        }
    }

    pub fn writeExt(self: *Encoder, type_id: i8, data: []const u8) EncodeError!void {
        const len = data.len;
        const tid: u8 = @bitCast(type_id);
        switch (len) {
            1 => try self.write1(Tag.fixext1),
            2 => try self.write1(Tag.fixext2),
            4 => try self.write1(Tag.fixext4),
            8 => try self.write1(Tag.fixext8),
            16 => try self.write1(Tag.fixext16),
            else => {
                if (len <= 0xff) {
                    try self.write1(Tag.ext8);
                    try self.write1(@intCast(len));
                } else if (len <= 0xffff) {
                    try self.write1(Tag.ext16);
                    try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u16, @intCast(len))));
                } else if (len <= 0xffffffff) {
                    try self.write1(Tag.ext32);
                    try self.writeN(&std.mem.toBytes(std.mem.nativeToBig(u32, @intCast(len))));
                } else {
                    return error.ContainerTooLarge;
                }
            },
        }
        try self.write1(tid);
        try self.writeN(data);
    }
};

test "encoder: positive fixint" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(0);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x00}, enc.written());
}

test "encoder: positive fixint max" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(127);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x7f}, enc.written());
}

test "encoder: uint8" {
    var buf: [2]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(128);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xcc, 0x80 }, enc.written());
}

test "encoder: uint16" {
    var buf: [3]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(256);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xcd, 0x01, 0x00 }, enc.written());
}

test "encoder: uint32" {
    var buf: [5]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(0x10000);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xce, 0x00, 0x01, 0x00, 0x00 }, enc.written());
}

test "encoder: uint64" {
    var buf: [9]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(std.math.maxInt(i64));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xcf, 0x7f, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff }, enc.written());
}

test "encoder: negative fixint min" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(-1);
    try std.testing.expectEqualSlices(u8, &[_]u8{0xff}, enc.written());
}

test "encoder: negative fixint -32" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(-32);
    try std.testing.expectEqualSlices(u8, &[_]u8{0xe0}, enc.written());
}

test "encoder: int8 -33" {
    var buf: [2]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(-33);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xd0, 0xdf }, enc.written());
}

test "encoder: int64 min" {
    var buf: [9]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeInt(std.math.minInt(i64));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xd3, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, enc.written());
}

test "encoder: nil" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeNil();
    try std.testing.expectEqualSlices(u8, &[_]u8{0xc0}, enc.written());
}

test "encoder: bool true" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeBool(true);
    try std.testing.expectEqualSlices(u8, &[_]u8{0xc3}, enc.written());
}

test "encoder: bool false" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeBool(false);
    try std.testing.expectEqualSlices(u8, &[_]u8{0xc2}, enc.written());
}

test "encoder: fixstr empty" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeStr("");
    try std.testing.expectEqualSlices(u8, &[_]u8{0xa0}, enc.written());
}

test "encoder: fixstr" {
    var buf: [6]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeStr("hello");
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xa5, 'h', 'e', 'l', 'l', 'o' }, enc.written());
}

test "encoder: fixarray" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeArrayHeader(3);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x93}, enc.written());
}

test "encoder: fixmap" {
    var buf: [1]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeMapHeader(2);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x82}, enc.written());
}

test "encoder: float32" {
    var buf: [5]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeFloat32(1.0);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xca, 0x3f, 0x80, 0x00, 0x00 }, enc.written());
}

test "encoder: float64" {
    var buf: [9]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeFloat64(1.0);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xcb, 0x3f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, enc.written());
}

test "encoder: bin8" {
    var buf: [4]u8 = undefined;
    var enc = Encoder.init(&buf);
    try enc.writeBin(&[_]u8{ 0x01, 0x02 });
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xc4, 0x02, 0x01, 0x02 }, enc.written());
}

test "encoder: buffer too small" {
    var buf: [0]u8 = undefined;
    var enc = Encoder.init(&buf);
    try std.testing.expectError(error.BufferTooSmall, enc.writeNil());
}
