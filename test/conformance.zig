// Conformance tests against msgpack-test-suite vectors
// See: https://github.com/kawanet/msgpack-test-suite
const std = @import("std");
const msgpack = @import("msgpack");
const helpers = @import("helpers.zig");

// nil
test "conformance: nil" {
    const bytes = helpers.hexToBytes("c0");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expect(v == .nil);
}

// bool
test "conformance: false" {
    const bytes = helpers.hexToBytes("c2");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .bool = false }, v);
}

test "conformance: true" {
    const bytes = helpers.hexToBytes("c3");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .bool = true }, v);
}

// Integers — positive fixint
test "conformance: int 0" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("00"), 0);
}

test "conformance: int 127" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("7f"), 127);
}

// Integers — uint formats
test "conformance: uint8 128" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("cc80"), 128);
}

test "conformance: uint8 255" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("ccff"), 255);
}

test "conformance: uint16 256" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("cd0100"), 256);
}

test "conformance: uint16 65535" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("cdffff"), 65535);
}

test "conformance: uint32 65536" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("ce00010000"), 65536);
}

// Integers — negative fixint
test "conformance: int -1" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("ff"), -1);
}

test "conformance: int -32" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("e0"), -32);
}

// Integers — int formats
test "conformance: int8 -33" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("d0df"), -33);
}

test "conformance: int8 -128" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("d080"), -128);
}

test "conformance: int16 -129" {
    try helpers.expectDecodeInt(&helpers.hexToBytes("d1ff7f"), -129);
}

// Float
test "conformance: float32 1.0" {
    const bytes = helpers.hexToBytes("ca3f800000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), v.float32, 1e-7);
}

test "conformance: float64 1.0" {
    const bytes = helpers.hexToBytes("cb3ff0000000000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), v.float64, 1e-15);
}

test "conformance: float32 NaN" {
    const bytes = helpers.hexToBytes("ca7fc00000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expect(std.math.isNan(v.float32));
}

test "conformance: float32 +Inf" {
    const bytes = helpers.hexToBytes("ca7f800000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expect(std.math.isPositiveInf(v.float32));
}

test "conformance: float32 -Inf" {
    const bytes = helpers.hexToBytes("caff800000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expect(std.math.isNegativeInf(v.float32));
}

// Strings
test "conformance: fixstr empty" {
    try helpers.expectDecodeStr(&helpers.hexToBytes("a0"), "");
}

test "conformance: fixstr hello" {
    try helpers.expectDecodeStr(&helpers.hexToBytes("a568656c6c6f"), "hello");
}

test "conformance: str8" {
    // str8 of "a" repeated 32 times
    var bytes: [34]u8 = undefined;
    bytes[0] = 0xd9;
    bytes[1] = 32;
    @memset(bytes[2..], 'a');
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(usize, 32), v.str.len);
}

// Binary
test "conformance: bin8 empty" {
    const bytes = helpers.hexToBytes("c400");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(usize, 0), v.bin.len);
}

test "conformance: bin8 two bytes" {
    const bytes = helpers.hexToBytes("c402aabb");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xaa, 0xbb }, v.bin);
}

// Arrays
test "conformance: fixarray empty" {
    const bytes = helpers.hexToBytes("90");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 0 }, v);
}

test "conformance: fixarray 3" {
    const bytes = helpers.hexToBytes("93");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 3 }, v);
}

// Maps
test "conformance: fixmap empty" {
    const bytes = helpers.hexToBytes("80");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .map = 0 }, v);
}

// Float +0.0 / -0.0
test "conformance: float32 +0.0" {
    const bytes = helpers.hexToBytes("ca00000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expect(v.float32 == 0.0);
    try std.testing.expect(!std.math.signbit(v.float32));
}

test "conformance: float32 -0.0" {
    const bytes = helpers.hexToBytes("ca80000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expect(v.float32 == 0.0);
    try std.testing.expect(std.math.signbit(v.float32));
}

test "conformance: float32 +0.5" {
    const bytes = helpers.hexToBytes("ca3f000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), v.float32, 1e-7);
}

test "conformance: float32 -0.5" {
    const bytes = helpers.hexToBytes("cabf000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), v.float32, 1e-7);
}

test "conformance: float64 +0.5" {
    const bytes = helpers.hexToBytes("cb3fe0000000000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), v.float64, 1e-15);
}

test "conformance: float64 NaN" {
    const bytes = helpers.hexToBytes("cb7ff8000000000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expect(std.math.isNan(v.float64));
}

test "conformance: float64 +Inf" {
    const bytes = helpers.hexToBytes("cb7ff0000000000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expect(std.math.isPositiveInf(v.float64));
}

test "conformance: float64 -Inf" {
    const bytes = helpers.hexToBytes("cbfff0000000000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expect(std.math.isNegativeInf(v.float64));
}

// Strings — boundaries
test "conformance: fixstr 31 bytes max" {
    // fixstr with 31 'a' chars: tag = 0xbf
    var bytes: [32]u8 = undefined;
    bytes[0] = 0xbf;
    @memset(bytes[1..], 'a');
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(usize, 31), v.str.len);
}

test "conformance: str8 32 bytes min" {
    // str8 with 32 bytes: tag=d9, len=0x20
    var bytes: [34]u8 = undefined;
    bytes[0] = 0xd9;
    bytes[1] = 32;
    @memset(bytes[2..], 'a');
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(usize, 32), v.str.len);
}

test "conformance: str16 empty" {
    const bytes = helpers.hexToBytes("da0000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(usize, 0), v.str.len);
}

test "conformance: str32 empty" {
    const bytes = helpers.hexToBytes("db00000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(usize, 0), v.str.len);
}

// Strings — UTF-8 (test-suite 31.string-utf8)
test "conformance: str Cyrillic" {
    // "Кириллица" — 18 bytes UTF-8, fixstr tag 0xb2
    const bytes = helpers.hexToBytes("b2d09ad0b8d180d0b8d0bbd0bbd0b8d186d0b0");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqualStrings("Кириллица", v.str);
}

test "conformance: str Japanese hiragana" {
    // "ひらがな" — 12 bytes UTF-8, fixstr tag 0xac
    const bytes = helpers.hexToBytes("ace381b2e38289e3818ce381aa");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqualStrings("ひらがな", v.str);
}

test "conformance: str Korean" {
    // "한글" — 6 bytes UTF-8, fixstr tag 0xa6
    const bytes = helpers.hexToBytes("a6ed959ceab880");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqualStrings("한글", v.str);
}

test "conformance: str Chinese simplified" {
    const bytes = helpers.hexToBytes("a6e6b189e5ad97");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqualStrings("汉字", v.str);
}

// Encoder: string boundary
test "conformance enc: fixstr 31 bytes" {
    var buf: [32]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeStr("a" ** 31);
    try std.testing.expectEqual(@as(u8, 0xbf), enc.written()[0]);
    try std.testing.expectEqual(@as(usize, 32), enc.written().len);
}

test "conformance enc: str8 32 bytes" {
    var buf: [34]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeStr("a" ** 32);
    try std.testing.expectEqual(@as(u8, 0xd9), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 32), enc.written()[1]);
}

test "conformance enc: str8 255 bytes max" {
    var buf: [257]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeStr("a" ** 255);
    try std.testing.expectEqual(@as(u8, 0xd9), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 0xff), enc.written()[1]);
    try std.testing.expectEqual(@as(usize, 257), enc.written().len);
}

test "conformance enc: str16 256 bytes min" {
    var buf: [259]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeStr("a" ** 256);
    try std.testing.expectEqual(@as(u8, 0xda), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 0x01), enc.written()[1]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[2]);
    try std.testing.expectEqual(@as(usize, 259), enc.written().len);
}

test "conformance enc: str16 65535 bytes max" {
    var data: [65535]u8 = undefined;
    @memset(&data, 'a');
    var buf: [65538]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeStr(&data);
    try std.testing.expectEqual(@as(u8, 0xda), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 0xff), enc.written()[1]);
    try std.testing.expectEqual(@as(u8, 0xff), enc.written()[2]);
    try std.testing.expectEqual(@as(usize, 65538), enc.written().len);
}

test "conformance enc: str32 65536 bytes min" {
    var data: [65536]u8 = undefined;
    @memset(&data, 'a');
    var buf: [65541]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeStr(&data);
    try std.testing.expectEqual(@as(u8, 0xdb), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[1]);
    try std.testing.expectEqual(@as(u8, 0x01), enc.written()[2]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[3]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[4]);
}

// Binary — bin16 / bin32
test "conformance: bin16 empty" {
    const bytes = helpers.hexToBytes("c50000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(usize, 0), v.bin.len);
}

test "conformance: bin32 empty" {
    const bytes = helpers.hexToBytes("c600000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(usize, 0), v.bin.len);
}

test "conformance: bin16 with data" {
    const bytes = helpers.hexToBytes("c500010101");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqualSlices(u8, &[_]u8{0x01}, v.bin);
}

// Arrays — all header formats
test "conformance: fixarray 15 max" {
    const bytes = helpers.hexToBytes("9f");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 15 }, v);
}

test "conformance: array16 header 16" {
    const bytes = helpers.hexToBytes("dc0010");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 16 }, v);
}

test "conformance: array16 empty" {
    const bytes = helpers.hexToBytes("dc0000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 0 }, v);
}

test "conformance: array32 empty" {
    const bytes = helpers.hexToBytes("dd00000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 0 }, v);
}

test "conformance enc: array 15" {
    var buf: [1]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeArrayHeader(15);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x9f}, enc.written());
}

test "conformance enc: array 16" {
    var buf: [3]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeArrayHeader(16);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xdc, 0x00, 0x10 }, enc.written());
}

// Maps — all header formats
test "conformance: fixmap 15 max" {
    const bytes = helpers.hexToBytes("8f");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .map = 15 }, v);
}

test "conformance: map16 header 16" {
    const bytes = helpers.hexToBytes("de0010");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .map = 16 }, v);
}

test "conformance: map16 empty" {
    const bytes = helpers.hexToBytes("de0000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .map = 0 }, v);
}

test "conformance: map32 empty" {
    const bytes = helpers.hexToBytes("df00000000");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .map = 0 }, v);
}

test "conformance enc: map 15" {
    var buf: [1]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeMapHeader(15);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x8f}, enc.written());
}

test "conformance enc: map 16" {
    var buf: [3]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeMapHeader(16);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xde, 0x00, 0x10 }, enc.written());
}

// Nested (test-suite 42.nested)
test "conformance: array of empty array [[]]" {
    // 91-90 : fixarray(1) [ fixarray(0) ]
    const bytes = helpers.hexToBytes("9190");
    var dec = msgpack.Decoder.init(&bytes);
    const outer = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 1 }, outer);
    const inner = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 0 }, inner);
}

test "conformance: array of empty map [{}]" {
    const bytes = helpers.hexToBytes("9180");
    var dec = msgpack.Decoder.init(&bytes);
    const outer = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 1 }, outer);
    const inner = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .map = 0 }, inner);
}

test "conformance: map of empty map {a: {}}" {
    // 81-a1-61-80
    const bytes = helpers.hexToBytes("81a16180");
    var dec = msgpack.Decoder.init(&bytes);
    const m = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .map = 1 }, m);
    const k = try dec.next();
    try std.testing.expectEqualStrings("a", k.str);
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .map = 0 }, v);
}

test "conformance: map of empty array {a: []}" {
    const bytes = helpers.hexToBytes("81a16190");
    var dec = msgpack.Decoder.init(&bytes);
    _ = try dec.next(); // map(1)
    _ = try dec.next(); // key "a"
    const v = try dec.next();
    try std.testing.expectEqual(msgpack.Value{ .array = 0 }, v);
}

// Extensions (test-suite 60.ext)
test "conformance: fixext1" {
    const bytes = helpers.hexToBytes("d40110");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(i8, 1), v.ext.type_id);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x10}, v.ext.data);
}

test "conformance: fixext2" {
    const bytes = helpers.hexToBytes("d5022021");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(i8, 2), v.ext.type_id);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x20, 0x21 }, v.ext.data);
}

test "conformance: fixext4" {
    const bytes = helpers.hexToBytes("d60330313233");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(i8, 3), v.ext.type_id);
    try std.testing.expectEqual(@as(usize, 4), v.ext.data.len);
}

test "conformance: fixext8" {
    const bytes = helpers.hexToBytes("d7044041424344454647");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(i8, 4), v.ext.type_id);
    try std.testing.expectEqual(@as(usize, 8), v.ext.data.len);
}

test "conformance: fixext16" {
    const bytes = helpers.hexToBytes("d805505152535455565758595a5b5c5d5e5f");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(i8, 5), v.ext.type_id);
    try std.testing.expectEqual(@as(usize, 16), v.ext.data.len);
}

test "conformance: ext8 size 0" {
    const bytes = helpers.hexToBytes("c70006");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqual(@as(i8, 6), v.ext.type_id);
    try std.testing.expectEqual(@as(usize, 0), v.ext.data.len);
}

test "conformance: ext8 size 3" {
    const raw = [_]u8{ 0xc7, 0x03, 0x07, 0x70, 0x71, 0x72 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    try std.testing.expectEqual(@as(i8, 7), v.ext.type_id);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x70, 0x71, 0x72 }, v.ext.data);
}

test "conformance: ext16 size 0" {
    const raw = [_]u8{ 0xc8, 0x00, 0x00, 0x06 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    try std.testing.expectEqual(@as(i8, 6), v.ext.type_id);
    try std.testing.expectEqual(@as(usize, 0), v.ext.data.len);
}

test "conformance: ext32 size 0" {
    const raw = [_]u8{ 0xc9, 0x00, 0x00, 0x00, 0x00, 0x06 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    try std.testing.expectEqual(@as(i8, 6), v.ext.type_id);
    try std.testing.expectEqual(@as(usize, 0), v.ext.data.len);
}

// Timestamps (test-suite 50.timestamp)
test "conformance: timestamp32 epoch" {
    // d6-ff-00-00-00-00 → [0, 0]
    const raw = [_]u8{ 0xd6, 0xff, 0x00, 0x00, 0x00, 0x00 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 0), ts.seconds);
    try std.testing.expectEqual(@as(u32, 0), ts.nanoseconds);
}

test "conformance: timestamp32 2018-01-02" {
    // d6-ff-5a-4a-f6-a5 → [1514862245, 0]
    const raw = [_]u8{ 0xd6, 0xff, 0x5a, 0x4a, 0xf6, 0xa5 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 1514862245), ts.seconds);
    try std.testing.expectEqual(@as(u32, 0), ts.nanoseconds);
}

test "conformance: timestamp32 max uint32" {
    // d6-ff-ff-ff-ff-ff → [4294967295, 0]
    const raw = [_]u8{ 0xd6, 0xff, 0xff, 0xff, 0xff, 0xff };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 4294967295), ts.seconds);
    try std.testing.expectEqual(@as(u32, 0), ts.nanoseconds);
}

test "conformance: timestamp64 with nanoseconds" {
    // d7-ff-a1-dc-d7-c8-5a-4a-f6-a5 → [1514862245, 678901234]
    const raw = [_]u8{ 0xd7, 0xff, 0xa1, 0xdc, 0xd7, 0xc8, 0x5a, 0x4a, 0xf6, 0xa5 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 1514862245), ts.seconds);
    try std.testing.expectEqual(@as(u32, 678901234), ts.nanoseconds);
}

test "conformance: timestamp64 ns max" {
    // d7-ff-ee-6b-27-fc-7f-ff-ff-ff → [2147483647, 999999999]
    const raw = [_]u8{ 0xd7, 0xff, 0xee, 0x6b, 0x27, 0xfc, 0x7f, 0xff, 0xff, 0xff };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 2147483647), ts.seconds);
    try std.testing.expectEqual(@as(u32, 999999999), ts.nanoseconds);
}

test "conformance: timestamp64 sec > uint32" {
    // d7-ff-00-00-00-01-00-00-00-00 → [4294967296, 0]
    const raw = [_]u8{ 0xd7, 0xff, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 4294967296), ts.seconds);
    try std.testing.expectEqual(@as(u32, 0), ts.nanoseconds);
}

test "conformance: timestamp96 negative seconds" {
    // c7-0c-ff-00-00-00-00-ff-ff-ff-ff-ff-ff-ff-ff → [-1, 0]
    const raw = [_]u8{ 0xc7, 0x0c, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, -1), ts.seconds);
    try std.testing.expectEqual(@as(u32, 0), ts.nanoseconds);
}

test "conformance: timestamp96 negative seconds with ns" {
    // c7-0c-ff-3b-9a-c9-ff-ff-ff-ff-ff-ff-ff-ff-ff → [-1, 999999999]
    const raw = [_]u8{ 0xc7, 0x0c, 0xff, 0x3b, 0x9a, 0xc9, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, -1), ts.seconds);
    try std.testing.expectEqual(@as(u32, 999999999), ts.nanoseconds);
}

test "conformance: timestamp96 year 9999" {
    // c7-0c-ff-3b-9a-c9-ff-00-00-00-3a-ff-f4-41-7f → [253402300799, 999999999]
    const raw = [_]u8{ 0xc7, 0x0c, 0xff, 0x3b, 0x9a, 0xc9, 0xff, 0x00, 0x00, 0x00, 0x3a, 0xff, 0xf4, 0x41, 0x7f };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 253402300799), ts.seconds);
    try std.testing.expectEqual(@as(u32, 999999999), ts.nanoseconds);
}

// Encoder conformance
test "conformance enc: nil roundtrip" {
    var buf: [1]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeNil();
    var dec = msgpack.Decoder.init(enc.written());
    const v = try dec.next();
    try std.testing.expect(v == .nil);
}

test "conformance enc: int roundtrip range" {
    const values = [_]i64{ 0, 1, 127, 128, 255, 256, -1, -32, -33, -128, -129, std.math.minInt(i64), std.math.maxInt(i64) };
    for (values) |expected| {
        var buf: [9]u8 = undefined;
        var enc = msgpack.Encoder.init(&buf);
        try enc.writeInt(expected);
        var dec = msgpack.Decoder.init(enc.written());
        const v = try dec.next();
        const got: i64 = switch (v) {
            .int => |i| i,
            .uint => |u| @intCast(u),
            else => return error.TypeMismatch,
        };
        try std.testing.expectEqual(expected, got);
    }
}

// Strings — additional Unicode
test "conformance: str 漢字" {
    // a6-e6-bc-a2-e5-ad-97 → "漢字" (6 bytes UTF-8, fixstr tag 0xa6)
    const bytes = helpers.hexToBytes("a6e6bca2e5ad97");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqualStrings("漢字", v.str);
}

// Binary — bin32
test "conformance: bin32 one byte" {
    // c6-00-00-00-01-01 → [0x01]
    const bytes = helpers.hexToBytes("c600000001" ++ "01");
    var dec = msgpack.Decoder.init(&bytes);
    const v = try dec.next();
    try std.testing.expectEqualSlices(u8, &[_]u8{0x01}, v.bin);
}

test "conformance enc: bin8 255 bytes" {
    var data: [255]u8 = undefined;
    @memset(&data, 0xab);
    var buf: [257]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeBin(&data);
    try std.testing.expectEqual(@as(u8, 0xc4), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 0xff), enc.written()[1]);
    try std.testing.expectEqual(@as(usize, 257), enc.written().len);
}

test "conformance enc: bin16 256 bytes" {
    var data: [256]u8 = undefined;
    @memset(&data, 0xcd);
    var buf: [259]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeBin(&data);
    try std.testing.expectEqual(@as(u8, 0xc5), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 0x01), enc.written()[1]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[2]);
    try std.testing.expectEqual(@as(usize, 259), enc.written().len);
}

test "conformance enc: bin32 65536 bytes" {
    var data: [65536]u8 = undefined;
    @memset(&data, 0x42);
    var buf: [65541]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeBin(&data);
    try std.testing.expectEqual(@as(u8, 0xc6), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[1]);
    try std.testing.expectEqual(@as(u8, 0x01), enc.written()[2]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[3]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[4]);
    try std.testing.expectEqual(@as(usize, 65541), enc.written().len);
}

// Arrays — large header encoder tests
test "conformance enc: array16 65535" {
    var buf: [3]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeArrayHeader(65535);
    try std.testing.expectEqual(@as(u8, 0xdc), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 0xff), enc.written()[1]);
    try std.testing.expectEqual(@as(u8, 0xff), enc.written()[2]);
}

test "conformance enc: array32 65536" {
    var buf: [5]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);
    try enc.writeArrayHeader(65536);
    try std.testing.expectEqual(@as(u8, 0xdd), enc.written()[0]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[1]);
    try std.testing.expectEqual(@as(u8, 0x01), enc.written()[2]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[3]);
    try std.testing.expectEqual(@as(u8, 0x00), enc.written()[4]);
}

// Timestamp — additional test-suite vectors
test "conformance: timestamp32 2147483648" {
    // d6-ff-80-00-00-00 → [2147483648, 0]
    const raw = [_]u8{ 0xd6, 0xff, 0x80, 0x00, 0x00, 0x00 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 2147483648), ts.seconds);
    try std.testing.expectEqual(@as(u32, 0), ts.nanoseconds);
}

test "conformance: timestamp64 [2147483648, 1]" {
    // d7-ff-00-00-00-04-80-00-00-00 → [2147483648, 1]
    const raw = [_]u8{ 0xd7, 0xff, 0x00, 0x00, 0x00, 0x04, 0x80, 0x00, 0x00, 0x00 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 2147483648), ts.seconds);
    try std.testing.expectEqual(@as(u32, 1), ts.nanoseconds);
}

test "conformance: timestamp64 max [17179869183, 999999999]" {
    // d7-ff-ee-6b-27-ff-ff-ff-ff-ff → [17179869183, 999999999]
    const raw = [_]u8{ 0xd7, 0xff, 0xee, 0x6b, 0x27, 0xff, 0xff, 0xff, 0xff, 0xff };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, 17179869183), ts.seconds);
    try std.testing.expectEqual(@as(u32, 999999999), ts.nanoseconds);
}

test "conformance: timestamp96 year 0001" {
    // c7-0c-ff-00-00-00-00-ff-ff-ff-f1-86-8b-84-00 → [-62167219200, 0]
    const raw = [_]u8{ 0xc7, 0x0c, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xf1, 0x86, 0x8b, 0x84, 0x00 };
    var dec = msgpack.Decoder.init(&raw);
    const v = try dec.next();
    const ts = try msgpack.Timestamp.decode(v.ext.data);
    try std.testing.expectEqual(@as(i64, -62167219200), ts.seconds);
    try std.testing.expectEqual(@as(u32, 0), ts.nanoseconds);
}
