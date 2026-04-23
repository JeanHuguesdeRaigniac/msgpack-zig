const std = @import("std");
const msgpack = @import("msgpack");

pub fn main() !void {
    var buf: [64]u8 = undefined;
    var enc = msgpack.Encoder.init(&buf);

    try enc.writeMapHeader(2);
    try enc.writeStr("name");
    try enc.writeStr("alice");
    try enc.writeStr("age");
    try enc.writeInt(30);

    const encoded = enc.written();
    std.debug.print("encoded {} bytes\n", .{encoded.len});

    var dec = msgpack.Decoder.init(encoded);
    const map = try dec.next();
    std.debug.print("map with {} pairs\n", .{map.map});

    var i: u32 = 0;
    while (i < map.map) : (i += 1) {
        const key = try dec.next();
        const val = try dec.next();
        std.debug.print("  {s}: ", .{key.str});
        switch (val) {
            .str => |s| std.debug.print("{s}\n", .{s}),
            .int => |n| std.debug.print("{}\n", .{n}),
            .uint => |n| std.debug.print("{}\n", .{n}),
            else => std.debug.print("(other)\n", .{}),
        }
    }
}
