# msgpack.org[Zig]

MessagePack implementation for Zig 0.16.0. No heap allocations. No dependencies.

## Features

- Encode into a caller-provided buffer — no allocation
- Decode from a buffer — string and binary values are slices into the original bytes, no copy
- Decode from any `std.Io.Reader` — reads bytes as they arrive, working memory proportional to the largest single value
- Skip values without buffering, including nested arrays and maps
- Full MessagePack spec v2.0: all integer, float, string, binary, array, map, and extension formats
- Timestamp extension (type -1) in 32-bit, 64-bit, and 96-bit formats
- Core unit tests + msgpack-test-suite conformance tests — Linux, macOS, Windows

## Quick example

```zig
const msgpack = @import("msgpack");

// Encode
var buf: [64]u8 = undefined;
var enc = msgpack.Encoder.init(&buf);
try enc.writeMapHeader(1);
try enc.writeStr("lang");
try enc.writeStr("zig");
const bytes = enc.written();

// Decode
var dec = msgpack.Decoder.init(bytes);
_ = try dec.next();            // map(1)
_ = try dec.next();            // "lang"
const v = try dec.next();      // "zig"
std.debug.print("{s}\n", .{v.str});
```

## Source

[https://github.com/JeanHuguesdeRaigniac/msgpack-zig](https://github.com/JeanHuguesdeRaigniac/msgpack-zig)

## License

MIT
