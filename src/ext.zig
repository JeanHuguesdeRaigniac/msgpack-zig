const std = @import("std");
const Encoder = @import("encoder.zig").Encoder;
const Decoder = @import("decoder.zig").Decoder;
const EncodeError = @import("encoder.zig").EncodeError;
const DecodeError = @import("decoder.zig").DecodeError;

pub const Timestamp = struct {
    seconds: i64,
    nanoseconds: u32,

    pub fn encode(self: Timestamp, enc: *Encoder) EncodeError!void {
        if (self.nanoseconds == 0 and self.seconds >= 0 and self.seconds <= 0xffffffff) {
            // timestamp32: fixext4 — 0 ≤ sec ≤ 2^32-1, ns=0
            var data: [4]u8 = undefined;
            std.mem.writeInt(u32, &data, @intCast(self.seconds), .big);
            try enc.writeExt(-1, &data);
        } else if (self.seconds >= 0 and self.seconds <= 0x3_ffff_ffff) {
            // timestamp64: fixext8 — 0 ≤ sec ≤ 2^34-1
            const value: u64 = (@as(u64, self.nanoseconds) << 34) | @as(u64, @intCast(self.seconds));
            var data: [8]u8 = undefined;
            std.mem.writeInt(u64, &data, value, .big);
            try enc.writeExt(-1, &data);
        } else {
            // timestamp96: ext8 len=12 — negative seconds or seconds >= 2^34
            var data: [12]u8 = undefined;
            std.mem.writeInt(u32, data[0..4], self.nanoseconds, .big);
            std.mem.writeInt(i64, data[4..12], self.seconds, .big);
            try enc.writeExt(-1, &data);
        }
    }

    pub fn decode(data: []const u8) DecodeError!Timestamp {
        return switch (data.len) {
            4 => .{
                .seconds = std.mem.readInt(u32, data[0..4], .big),
                .nanoseconds = 0,
            },
            8 => blk: {
                const raw = std.mem.readInt(u64, data[0..8], .big);
                const ns: u32 = @intCast(raw >> 34);
                if (ns > 999_999_999) return error.TypeMismatch;
                const sec: i64 = @intCast(raw & 0x3_ffff_ffff);
                break :blk .{ .seconds = sec, .nanoseconds = ns };
            },
            12 => blk: {
                const ns = std.mem.readInt(u32, data[0..4], .big);
                if (ns > 999_999_999) return error.TypeMismatch;
                const sec = std.mem.readInt(i64, data[4..12], .big);
                break :blk .{ .seconds = sec, .nanoseconds = ns };
            },
            else => error.TypeMismatch,
        };
    }
};

test "timestamp: encode 32-bit" {
    var buf: [6]u8 = undefined;
    var enc = Encoder.init(&buf);
    const ts = Timestamp{ .seconds = 1, .nanoseconds = 0 };
    try ts.encode(&enc);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xd6, 0xff, 0x00, 0x00, 0x00, 0x01 }, enc.written());
}

test "timestamp: encode 64-bit with nanoseconds" {
    var buf: [10]u8 = undefined;
    var enc = Encoder.init(&buf);
    const ts = Timestamp{ .seconds = 1, .nanoseconds = 500000000 };
    try ts.encode(&enc);
    const written = enc.written();
    try std.testing.expectEqual(@as(u8, 0xd7), written[0]);
    try std.testing.expectEqual(@as(u8, 0xff), written[1]);
    const decoded = try Timestamp.decode(written[2..]);
    try std.testing.expectEqual(ts.seconds, decoded.seconds);
    try std.testing.expectEqual(ts.nanoseconds, decoded.nanoseconds);
}

test "timestamp: encode 96-bit negative seconds" {
    var buf: [15]u8 = undefined;
    var enc = Encoder.init(&buf);
    const ts = Timestamp{ .seconds = -1, .nanoseconds = 0 };
    try ts.encode(&enc);
    const written = enc.written();
    // ext8: c7, len=12, type=-1 (ff)
    try std.testing.expectEqual(@as(u8, 0xc7), written[0]);
    try std.testing.expectEqual(@as(u8, 0x0c), written[1]);
    try std.testing.expectEqual(@as(u8, 0xff), written[2]);
    const decoded = try Timestamp.decode(written[3..]);
    try std.testing.expectEqual(ts.seconds, decoded.seconds);
    try std.testing.expectEqual(ts.nanoseconds, decoded.nanoseconds);
}

test "timestamp: encode 96-bit large seconds" {
    var buf: [15]u8 = undefined;
    var enc = Encoder.init(&buf);
    const ts = Timestamp{ .seconds = 17179869184, .nanoseconds = 0 }; // 2^34
    try ts.encode(&enc);
    const written = enc.written();
    try std.testing.expectEqual(@as(u8, 0xc7), written[0]);
    const decoded = try Timestamp.decode(written[3..]);
    try std.testing.expectEqual(ts.seconds, decoded.seconds);
}

test "timestamp: roundtrip 32-bit" {
    var buf: [6]u8 = undefined;
    var enc = Encoder.init(&buf);
    const ts = Timestamp{ .seconds = 1700000000, .nanoseconds = 0 };
    try ts.encode(&enc);
    const decoded = try Timestamp.decode(enc.written()[2..]);
    try std.testing.expectEqual(ts.seconds, decoded.seconds);
    try std.testing.expectEqual(ts.nanoseconds, decoded.nanoseconds);
}

test "timestamp: decode invalid ns in 64-bit format" {
    // Construct a timestamp64 with ns > 999999999
    // raw = (1_000_000_000 << 34) | 1 — ns field overflows valid range
    const raw: u64 = (@as(u64, 1_000_000_000) << 34) | 1;
    var data: [8]u8 = undefined;
    std.mem.writeInt(u64, &data, raw, .big);
    try std.testing.expectError(error.TypeMismatch, Timestamp.decode(&data));
}

test "timestamp: decode invalid ns in 96-bit format" {
    var data: [12]u8 = undefined;
    std.mem.writeInt(u32, data[0..4], 1_000_000_000, .big);
    std.mem.writeInt(i64, data[4..12], 0, .big);
    try std.testing.expectError(error.TypeMismatch, Timestamp.decode(&data));
}

test "timestamp: decode invalid size" {
    const data = [_]u8{ 0x01 }; // size=1 — invalid
    try std.testing.expectError(error.TypeMismatch, Timestamp.decode(&data));
}
