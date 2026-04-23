const std = @import("std");
const types = @import("types.zig");
const Tag = types.Tag;

pub const DecodeError = error{
    UnexpectedEof,
    UnknownTag,
    ReservedTag,
    MaxDepth,
    InvalidUtf8,
    TypeMismatch,
};

pub const ExtValue = struct {
    type_id: i8,
    data: []const u8,
};

pub const Value = union(enum) {
    nil,
    bool: bool,
    int: i64,
    uint: u64,
    float32: f32,
    float64: f64,
    str: []const u8,
    bin: []const u8,
    array: u32,
    map: u32,
    ext: ExtValue,
};

pub const Decoder = struct {
    buf: []const u8,
    pos: usize,
    depth: usize,

    const max_depth = 64;

    pub fn init(buf: []const u8) Decoder {
        return .{ .buf = buf, .pos = 0, .depth = 0 };
    }

    fn read1(self: *Decoder) DecodeError!u8 {
        if (self.pos >= self.buf.len) return error.UnexpectedEof;
        const b = self.buf[self.pos];
        self.pos += 1;
        return b;
    }

    fn readN(self: *Decoder, n: usize) DecodeError![]const u8 {
        if (self.pos + n > self.buf.len) return error.UnexpectedEof;
        const slice = self.buf[self.pos .. self.pos + n];
        self.pos += n;
        return slice;
    }

    fn readU16(self: *Decoder) DecodeError!u16 {
        const bytes = try self.readN(2);
        return std.mem.bigToNative(u16, std.mem.bytesToValue(u16, bytes[0..2]));
    }

    fn readU32(self: *Decoder) DecodeError!u32 {
        const bytes = try self.readN(4);
        return std.mem.bigToNative(u32, std.mem.bytesToValue(u32, bytes[0..4]));
    }

    fn readU64(self: *Decoder) DecodeError!u64 {
        const bytes = try self.readN(8);
        return std.mem.bigToNative(u64, std.mem.bytesToValue(u64, bytes[0..8]));
    }

    fn readI8(self: *Decoder) DecodeError!i8 {
        return @bitCast(try self.read1());
    }

    fn readI16(self: *Decoder) DecodeError!i16 {
        const bytes = try self.readN(2);
        return std.mem.bigToNative(i16, std.mem.bytesToValue(i16, bytes[0..2]));
    }

    fn readI32(self: *Decoder) DecodeError!i32 {
        const bytes = try self.readN(4);
        return std.mem.bigToNative(i32, std.mem.bytesToValue(i32, bytes[0..4]));
    }

    fn readI64(self: *Decoder) DecodeError!i64 {
        const bytes = try self.readN(8);
        return std.mem.bigToNative(i64, std.mem.bytesToValue(i64, bytes[0..8]));
    }

    pub fn next(self: *Decoder) DecodeError!Value {
        const tag = try self.read1();

        // positive fixint 0x00–0x7f
        if (tag <= 0x7f) return .{ .int = @intCast(tag) };

        // negative fixint 0xe0–0xff
        if (tag >= 0xe0) return .{ .int = @as(i64, @as(i8, @bitCast(tag))) };

        // fixmap 0x80–0x8f
        if (tag >= 0x80 and tag <= 0x8f) {
            if (self.depth >= max_depth) return error.MaxDepth;
            return .{ .map = tag & 0x0f };
        }

        // fixarray 0x90–0x9f
        if (tag >= 0x90 and tag <= 0x9f) {
            if (self.depth >= max_depth) return error.MaxDepth;
            return .{ .array = tag & 0x0f };
        }

        // fixstr 0xa0–0xbf
        if (tag >= 0xa0 and tag <= 0xbf) {
            const len: usize = tag & 0x1f;
            const bytes = try self.readN(len);
            return .{ .str = bytes };
        }

        return switch (tag) {
            Tag.nil => .nil,
            Tag.@"false" => .{ .bool = false },
            Tag.@"true" => .{ .bool = true },
            Tag.reserved => error.ReservedTag,

            Tag.bin8 => blk: {
                const len = try self.read1();
                break :blk .{ .bin = try self.readN(len) };
            },
            Tag.bin16 => blk: {
                const len = try self.readU16();
                break :blk .{ .bin = try self.readN(len) };
            },
            Tag.bin32 => blk: {
                const len = try self.readU32();
                break :blk .{ .bin = try self.readN(len) };
            },

            Tag.float32 => blk: {
                const raw = try self.readU32();
                break :blk .{ .float32 = @bitCast(raw) };
            },
            Tag.float64 => blk: {
                const raw = try self.readU64();
                break :blk .{ .float64 = @bitCast(raw) };
            },

            Tag.uint8 => .{ .uint = try self.read1() },
            Tag.uint16 => .{ .uint = try self.readU16() },
            Tag.uint32 => .{ .uint = try self.readU32() },
            Tag.uint64 => .{ .uint = try self.readU64() },

            Tag.int8 => .{ .int = try self.readI8() },
            Tag.int16 => .{ .int = try self.readI16() },
            Tag.int32 => .{ .int = try self.readI32() },
            Tag.int64 => .{ .int = try self.readI64() },

            Tag.fixext1 => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readN(1) } };
            },
            Tag.fixext2 => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readN(2) } };
            },
            Tag.fixext4 => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readN(4) } };
            },
            Tag.fixext8 => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readN(8) } };
            },
            Tag.fixext16 => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readN(16) } };
            },
            Tag.ext8 => blk: {
                const len = try self.read1();
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readN(len) } };
            },
            Tag.ext16 => blk: {
                const len = try self.readU16();
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readN(len) } };
            },
            Tag.ext32 => blk: {
                const len = try self.readU32();
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readN(len) } };
            },

            Tag.str8 => blk: {
                const len = try self.read1();
                break :blk .{ .str = try self.readN(len) };
            },
            Tag.str16 => blk: {
                const len = try self.readU16();
                break :blk .{ .str = try self.readN(len) };
            },
            Tag.str32 => blk: {
                const len = try self.readU32();
                break :blk .{ .str = try self.readN(len) };
            },

            Tag.array16 => blk: {
                if (self.depth >= max_depth) return error.MaxDepth;
                break :blk .{ .array = try self.readU16() };
            },
            Tag.array32 => blk: {
                if (self.depth >= max_depth) return error.MaxDepth;
                break :blk .{ .array = try self.readU32() };
            },

            Tag.map16 => blk: {
                if (self.depth >= max_depth) return error.MaxDepth;
                break :blk .{ .map = try self.readU16() };
            },
            Tag.map32 => blk: {
                if (self.depth >= max_depth) return error.MaxDepth;
                break :blk .{ .map = try self.readU32() };
            },

            else => error.UnknownTag,
        };
    }
};

test "decoder: nil" {
    var dec = Decoder.init(&[_]u8{0xc0});
    const v = try dec.next();
    try std.testing.expect(v == .nil);
}

test "decoder: bool true" {
    var dec = Decoder.init(&[_]u8{0xc3});
    const v = try dec.next();
    try std.testing.expectEqual(Value{ .bool = true }, v);
}

test "decoder: bool false" {
    var dec = Decoder.init(&[_]u8{0xc2});
    const v = try dec.next();
    try std.testing.expectEqual(Value{ .bool = false }, v);
}

test "decoder: positive fixint" {
    var dec = Decoder.init(&[_]u8{0x7f});
    const v = try dec.next();
    try std.testing.expectEqual(Value{ .int = 127 }, v);
}

test "decoder: negative fixint" {
    var dec = Decoder.init(&[_]u8{0xe0});
    const v = try dec.next();
    try std.testing.expectEqual(Value{ .int = -32 }, v);
}

test "decoder: uint8" {
    var dec = Decoder.init(&[_]u8{ 0xcc, 0x80 });
    const v = try dec.next();
    try std.testing.expectEqual(Value{ .uint = 128 }, v);
}

test "decoder: int8" {
    var dec = Decoder.init(&[_]u8{ 0xd0, 0xdf });
    const v = try dec.next();
    try std.testing.expectEqual(Value{ .int = -33 }, v);
}

test "decoder: fixstr" {
    var dec = Decoder.init(&[_]u8{ 0xa5, 'h', 'e', 'l', 'l', 'o' });
    const v = try dec.next();
    try std.testing.expectEqualStrings("hello", v.str);
}

test "decoder: fixarray header" {
    var dec = Decoder.init(&[_]u8{0x93});
    const v = try dec.next();
    try std.testing.expectEqual(Value{ .array = 3 }, v);
}

test "decoder: fixmap header" {
    var dec = Decoder.init(&[_]u8{0x82});
    const v = try dec.next();
    try std.testing.expectEqual(Value{ .map = 2 }, v);
}

test "decoder: float32" {
    var dec = Decoder.init(&[_]u8{ 0xca, 0x3f, 0x80, 0x00, 0x00 });
    const v = try dec.next();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), v.float32, 1e-6);
}

test "decoder: unexpected eof" {
    var dec = Decoder.init(&[_]u8{0xcc});
    try std.testing.expectError(error.UnexpectedEof, dec.next());
}

test "decoder: reserved tag 0xc1" {
    var dec = Decoder.init(&[_]u8{0xc1});
    try std.testing.expectError(error.ReservedTag, dec.next());
}
