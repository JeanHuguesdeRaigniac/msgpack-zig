// StreamDecoder — Reader-based decoder for msgpack v2.0 (Zig 0.16.0).
//
// Design: next(buf) is the primary API.
// str/bin/ext data is copied into the caller's buf on each next() call.
// For scalars and array/map headers, buf is unused; pass &[_]u8{}.
//
// skipValue() discards a complete value (including nested containers)
// iteratively — no recursion, no stack growth.
//
// After error.BufferTooSmall the stream is in an undefined state.
// Size the buf for the largest expected payload.
const std = @import("std");
const Value = @import("decoder.zig").Value;
const ExtValue = @import("decoder.zig").ExtValue;
const Tag = @import("types.zig").Tag;

pub const StreamDecoder = struct {
    reader: *std.Io.Reader,

    pub fn init(reader: *std.Io.Reader) StreamDecoder {
        return .{ .reader = reader };
    }

    // ------------------------------------------------------------------ read helpers

    fn readExact(self: *StreamDecoder, buf: []u8) anyerror!void {
        self.reader.readSliceAll(buf) catch |err| switch (err) {
            error.EndOfStream => return error.UnexpectedEof,
            else => |e| return e,
        };
    }

    fn read1(self: *StreamDecoder) anyerror!u8 {
        var b: [1]u8 = undefined;
        try self.readExact(&b);
        return b[0];
    }

    fn readU16(self: *StreamDecoder) anyerror!u16 {
        var b: [2]u8 = undefined;
        try self.readExact(&b);
        return std.mem.readInt(u16, &b, .big);
    }

    fn readU32(self: *StreamDecoder) anyerror!u32 {
        var b: [4]u8 = undefined;
        try self.readExact(&b);
        return std.mem.readInt(u32, &b, .big);
    }

    fn readU64(self: *StreamDecoder) anyerror!u64 {
        var b: [8]u8 = undefined;
        try self.readExact(&b);
        return std.mem.readInt(u64, &b, .big);
    }

    fn readI8(self: *StreamDecoder) anyerror!i8 {
        return @bitCast(try self.read1());
    }

    fn readI16(self: *StreamDecoder) anyerror!i16 {
        var b: [2]u8 = undefined;
        try self.readExact(&b);
        return std.mem.readInt(i16, &b, .big);
    }

    fn readI32(self: *StreamDecoder) anyerror!i32 {
        var b: [4]u8 = undefined;
        try self.readExact(&b);
        return std.mem.readInt(i32, &b, .big);
    }

    fn readI64(self: *StreamDecoder) anyerror!i64 {
        var b: [8]u8 = undefined;
        try self.readExact(&b);
        return std.mem.readInt(i64, &b, .big);
    }

    fn skipN(self: *StreamDecoder, n: u64) anyerror!void {
        var remaining = n;
        var discard: [64]u8 = undefined;
        while (remaining > 0) {
            const chunk: usize = if (remaining > discard.len) discard.len else @intCast(remaining);
            try self.readExact(discard[0..chunk]);
            remaining -= chunk;
        }
    }

    fn readIntoBuf(self: *StreamDecoder, len: usize, buf: []u8) anyerror![]u8 {
        if (len > buf.len) return error.BufferTooSmall;
        try self.readExact(buf[0..len]);
        return buf[0..len];
    }

    // ------------------------------------------------------------------ next

    /// Decode one value from the stream.
    ///
    /// buf is used as storage for str, bin and ext payloads. The returned
    /// Value.str/.bin/.ext.data slices point into buf and are valid until
    /// the next call to next() or skipValue().
    ///
    /// For scalars and array/map headers buf is ignored; pass &[_]u8{}.
    pub fn next(self: *StreamDecoder, buf: []u8) anyerror!Value {
        const tag = try self.read1();

        if (tag <= 0x7f) return .{ .int = @intCast(tag) };
        if (tag >= 0xe0) return .{ .int = @as(i64, @as(i8, @bitCast(tag))) };
        if (tag >= 0x80 and tag <= 0x8f) return .{ .map = tag & 0x0f };
        if (tag >= 0x90 and tag <= 0x9f) return .{ .array = tag & 0x0f };
        if (tag >= 0xa0 and tag <= 0xbf) {
            const len: usize = tag & 0x1f;
            return .{ .str = try self.readIntoBuf(len, buf) };
        }

        return switch (tag) {
            Tag.nil      => .nil,
            Tag.@"false" => .{ .bool = false },
            Tag.@"true"  => .{ .bool = true },
            Tag.reserved => error.ReservedTag,

            Tag.uint8  => .{ .uint = try self.read1() },
            Tag.uint16 => .{ .uint = try self.readU16() },
            Tag.uint32 => .{ .uint = try self.readU32() },
            Tag.uint64 => .{ .uint = try self.readU64() },

            Tag.int8  => .{ .int = try self.readI8() },
            Tag.int16 => .{ .int = try self.readI16() },
            Tag.int32 => .{ .int = try self.readI32() },
            Tag.int64 => .{ .int = try self.readI64() },

            Tag.float32 => blk: {
                var raw: [4]u8 = undefined;
                try self.readExact(&raw);
                break :blk .{ .float32 = @bitCast(std.mem.readInt(u32, &raw, .big)) };
            },
            Tag.float64 => blk: {
                var raw: [8]u8 = undefined;
                try self.readExact(&raw);
                break :blk .{ .float64 = @bitCast(std.mem.readInt(u64, &raw, .big)) };
            },

            Tag.str8  => .{ .str = try self.readIntoBuf(try self.read1(), buf) },
            Tag.str16 => .{ .str = try self.readIntoBuf(try self.readU16(), buf) },
            Tag.str32 => .{ .str = try self.readIntoBuf(try self.readU32(), buf) },

            Tag.bin8  => .{ .bin = try self.readIntoBuf(try self.read1(), buf) },
            Tag.bin16 => .{ .bin = try self.readIntoBuf(try self.readU16(), buf) },
            Tag.bin32 => .{ .bin = try self.readIntoBuf(try self.readU32(), buf) },

            Tag.array16 => .{ .array = try self.readU16() },
            Tag.array32 => .{ .array = try self.readU32() },
            Tag.map16   => .{ .map = try self.readU16() },
            Tag.map32   => .{ .map = try self.readU32() },

            Tag.fixext1  => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readIntoBuf(1, buf) } };
            },
            Tag.fixext2  => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readIntoBuf(2, buf) } };
            },
            Tag.fixext4  => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readIntoBuf(4, buf) } };
            },
            Tag.fixext8  => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readIntoBuf(8, buf) } };
            },
            Tag.fixext16 => blk: {
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readIntoBuf(16, buf) } };
            },
            Tag.ext8  => blk: {
                const len = try self.read1();
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readIntoBuf(len, buf) } };
            },
            Tag.ext16 => blk: {
                const len = try self.readU16();
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readIntoBuf(len, buf) } };
            },
            Tag.ext32 => blk: {
                const len = try self.readU32();
                const tid = try self.readI8();
                break :blk .{ .ext = .{ .type_id = tid, .data = try self.readIntoBuf(len, buf) } };
            },

            else => error.UnknownTag,
        };
    }

    // ------------------------------------------------------------------ skipValue

    /// Discard the next complete value without buffering its content.
    ///
    /// Works for nested containers iteratively — no recursion, no stack growth.
    pub fn skipValue(self: *StreamDecoder) anyerror!void {
        var pending: u64 = 1;
        while (pending > 0) {
            pending -= 1;
            const tag = try self.read1();

            if (tag <= 0x7f) continue;
            if (tag >= 0xe0) continue;
            if (tag >= 0x80 and tag <= 0x8f) {
                pending += 2 * @as(u64, tag & 0x0f);
                continue;
            }
            if (tag >= 0x90 and tag <= 0x9f) {
                pending += tag & 0x0f;
                continue;
            }
            if (tag >= 0xa0 and tag <= 0xbf) {
                try self.skipN(tag & 0x1f);
                continue;
            }

            switch (tag) {
                Tag.nil, Tag.@"false", Tag.@"true" => {},
                Tag.reserved => return error.ReservedTag,

                Tag.uint8,  Tag.int8                    => try self.skipN(1),
                Tag.uint16, Tag.int16                   => try self.skipN(2),
                Tag.uint32, Tag.int32, Tag.float32      => try self.skipN(4),
                Tag.uint64, Tag.int64, Tag.float64      => try self.skipN(8),

                Tag.str8,  Tag.bin8  => try self.skipN(try self.read1()),
                Tag.str16, Tag.bin16 => try self.skipN(try self.readU16()),
                Tag.str32, Tag.bin32 => try self.skipN(try self.readU32()),

                Tag.array16 => { pending += try self.readU16(); },
                Tag.array32 => { pending += try self.readU32(); },
                Tag.map16   => { pending += 2 * @as(u64, try self.readU16()); },
                Tag.map32   => { pending += 2 * @as(u64, try self.readU32()); },

                Tag.fixext1  => try self.skipN(1 + 1),
                Tag.fixext2  => try self.skipN(1 + 2),
                Tag.fixext4  => try self.skipN(1 + 4),
                Tag.fixext8  => try self.skipN(1 + 8),
                Tag.fixext16 => try self.skipN(1 + 16),
                Tag.ext8  => { const len = try self.read1();   try self.skipN(1 + @as(u64, len)); },
                Tag.ext16 => { const len = try self.readU16(); try self.skipN(1 + @as(u64, len)); },
                Tag.ext32 => { const len = try self.readU32(); try self.skipN(1 + @as(u64, len)); },

                else => return error.UnknownTag,
            }
        }
    }
};
