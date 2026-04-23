const std = @import("std");
const msgpack = @import("msgpack");

pub fn hexToBytes(comptime hex: []const u8) [hex.len / 2]u8 {
    var result: [hex.len / 2]u8 = undefined;
    var i: usize = 0;
    while (i < hex.len / 2) : (i += 1) {
        const hi = std.fmt.charToDigit(hex[i * 2], 16) catch unreachable;
        const lo = std.fmt.charToDigit(hex[i * 2 + 1], 16) catch unreachable;
        result[i] = (hi << 4) | lo;
    }
    return result;
}

pub fn expectDecodeInt(bytes: []const u8, expected: i64) !void {
    var dec = msgpack.Decoder.init(bytes);
    const val = try dec.next();
    switch (val) {
        .int => |v| try std.testing.expectEqual(expected, v),
        .uint => |v| try std.testing.expectEqual(@as(u64, @bitCast(expected)), v),
        else => return error.TypeMismatch,
    }
}

pub fn expectDecodeStr(bytes: []const u8, expected: []const u8) !void {
    var dec = msgpack.Decoder.init(bytes);
    const val = try dec.next();
    try std.testing.expectEqualStrings(expected, val.str);
}
