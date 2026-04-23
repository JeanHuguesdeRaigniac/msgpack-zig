# msgpack-zig

[MessagePack](https://msgpack.org) for Zig 0.16.0 — no heap allocations, no dependencies.

[![CI](https://github.com/JeanHuguesdeRaigniac/msgpack-zig/actions/workflows/ci.yml/badge.svg)](https://github.com/JeanHuguesdeRaigniac/msgpack-zig/actions)
[![Zig 0.16.0](https://img.shields.io/badge/zig-0.16.0-orange)](https://ziglang.org/download/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

## Installation

Add to `build.zig.zon`:

```zig
.dependencies = .{
    .msgpack = .{
        .url = "https://github.com/JeanHuguesdeRaigniac/msgpack-zig/archive/v0.2.0.tar.gz",
        .hash = "...",  // zig fetch --save <url>
    },
},
```

Add to `build.zig`:

```zig
const msgpack = b.dependency("msgpack", .{}).module("msgpack");
exe.root_module.addImport("msgpack", msgpack);
```

## Encoding

Write MessagePack into a buffer you provide:

```zig
const msgpack = @import("msgpack");

var buf: [64]u8 = undefined;
var enc = msgpack.Encoder.init(&buf);

try enc.writeMapHeader(2);
try enc.writeStr("name");
try enc.writeStr("alice");
try enc.writeStr("age");
try enc.writeInt(30);

const bytes: []const u8 = enc.written(); // ready to send
```

### Encoder methods

| Method | What it writes |
|--------|----------------|
| `writeNil()` | nil |
| `writeBool(bool)` | true or false |
| `writeInt(i64)` | integer (smallest encoding) |
| `writeUint(u64)` | unsigned integer (smallest encoding) |
| `writeFloat32(f32)` | 32-bit float |
| `writeFloat64(f64)` | 64-bit float |
| `writeStr([]const u8)` | UTF-8 string |
| `writeBin([]const u8)` | raw bytes |
| `writeArrayHeader(u32)` | array header — write elements after |
| `writeMapHeader(u32)` | map header — write key-value pairs after |
| `writeExt(i8, []const u8)` | extension type |

All methods return `error{ BufferTooSmall, StringTooLong, BinaryTooLong, ContainerTooLarge }!void`.

## Decoding from a buffer

When the full message is already in memory, use `Decoder`. Call `next()` once per value; for arrays and maps it returns the element count, then you call `next()` for each element.

```zig
var dec = msgpack.Decoder.init(bytes);

const header = try dec.next(); // .map = 2
const key1   = try dec.next(); // .str = "name"
const val1   = try dec.next(); // .str = "alice"
const key2   = try dec.next(); // .str = "age"
const val2   = try dec.next(); // .int = 30

_ = header; _ = key1; _ = val1; _ = key2;
std.debug.print("age: {}\n", .{val2.int});
```

String and binary values point directly into your original buffer — no copies are made.

## Decoding from a stream

When you receive bytes incrementally (a socket, a file, a pipe), use `StreamDecoder`. It reads bytes as they arrive without needing the entire message upfront. You supply a small working buffer to hold each string or binary payload as it is read.

```zig
var reader = std.Io.Reader.fixed(bytes); // or any std.Io.Reader
var dec = msgpack.StreamDecoder.init(&reader);

var buf: [256]u8 = undefined; // working storage for string/binary values

const header = try dec.next(&buf); // .map = 2
const key1   = try dec.next(&buf); // .str = "name"  — copied into buf
const val1   = try dec.next(&buf); // .str = "alice"
```

For numbers, booleans, nil, and container headers, `buf` is not used; any size works.

String and binary slices are valid until the next call to `next()`. Copy them if you need to keep them longer.

### Skipping values

`StreamDecoder` can discard a complete value — including nested arrays and maps — without a buffer:

```zig
try dec.skipValue(); // skip whatever comes next
```

## Timestamps

The MessagePack timestamp extension (type -1) is supported in all three formats:

```zig
// Encode
const ts = msgpack.Timestamp{ .seconds = 1700000000, .nanoseconds = 500000000 };
try ts.encode(&enc);

// Decode
const v  = try dec.next(); // or dec.next(&buf) for StreamDecoder
const ts = try msgpack.Timestamp.decode(v.ext.data);
```

`encode` picks the most compact format automatically.

## Values

Both decoders return the same type:

```zig
Value = union(enum) {
    nil,
    bool:    bool,
    int:     i64,
    uint:    u64,
    float32: f32,
    float64: f64,
    str:     []const u8,
    bin:     []const u8,
    array:   u32,   // element count
    map:     u32,   // key-value pair count
    ext:     ExtValue,
}

ExtValue = struct { type_id: i8, data: []const u8 }
```

## Errors

```zig
// Encoder
EncodeError = error{ BufferTooSmall, StringTooLong, BinaryTooLong, ContainerTooLarge }

// Decoder (buffer)
DecodeError = error{ UnexpectedEof, ReservedTag, UnknownTag, TypeMismatch, InvalidUtf8, MaxDepth }

// StreamDecoder
// returns anyerror — includes UnexpectedEof, ReservedTag, UnknownTag, BufferTooSmall
```

## Choosing a decoder

| | `Decoder` | `StreamDecoder` |
|---|---|---|
| Needs the full message in memory first | Yes | No |
| String values — no copy | Yes | No (copies into your buf) |
| Works with `std.Io.Reader` | No | Yes |
| Skip a value without a buffer | No | Yes |

## Supported formats

All MessagePack format types are covered: positive and negative fixint, uint8/16/32/64, int8/16/32/64, float32, float64, fixstr, str8/16/32, bin8/16/32, fixarray, array16/32, fixmap, map16/32, fixext1/2/4/8/16, ext8/16/32, and the timestamp extension (fixext4, fixext8, ext8 len=12).

This repository keeps the core library tests plus the msgpack-test-suite conformance tests.

## License

MIT — see [LICENSE](LICENSE).
