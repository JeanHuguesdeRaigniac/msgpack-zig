// MessagePack format tags — spec v2.0
pub const Tag = struct {
    // Fixed formats
    pub const positive_fixint_max: u8 = 0x7f;
    pub const fixmap_base: u8 = 0x80;
    pub const fixmap_mask: u8 = 0x8f;
    pub const fixarray_base: u8 = 0x90;
    pub const fixarray_mask: u8 = 0x9f;
    pub const fixstr_base: u8 = 0xa0;
    pub const fixstr_mask: u8 = 0xbf;
    pub const negative_fixint_base: u8 = 0xe0;

    // Nil / Bool
    pub const nil: u8 = 0xc0;
    pub const @"false": u8 = 0xc2;
    pub const @"true": u8 = 0xc3;

    // Reserved (must produce error on decode)
    pub const reserved: u8 = 0xc1;

    // Binary
    pub const bin8: u8 = 0xc4;
    pub const bin16: u8 = 0xc5;
    pub const bin32: u8 = 0xc6;

    // Extension
    pub const fixext1: u8 = 0xd4;
    pub const fixext2: u8 = 0xd5;
    pub const fixext4: u8 = 0xd6;
    pub const fixext8: u8 = 0xd7;
    pub const fixext16: u8 = 0xd8;
    pub const ext8: u8 = 0xc7;
    pub const ext16: u8 = 0xc8;
    pub const ext32: u8 = 0xc9;

    // Float
    pub const float32: u8 = 0xca;
    pub const float64: u8 = 0xcb;

    // Unsigned integers
    pub const uint8: u8 = 0xcc;
    pub const uint16: u8 = 0xcd;
    pub const uint32: u8 = 0xce;
    pub const uint64: u8 = 0xcf;

    // Signed integers
    pub const int8: u8 = 0xd0;
    pub const int16: u8 = 0xd1;
    pub const int32: u8 = 0xd2;
    pub const int64: u8 = 0xd3;

    // String
    pub const str8: u8 = 0xd9;
    pub const str16: u8 = 0xda;
    pub const str32: u8 = 0xdb;

    // Array
    pub const array16: u8 = 0xdc;
    pub const array32: u8 = 0xdd;

    // Map
    pub const map16: u8 = 0xde;
    pub const map32: u8 = 0xdf;

    // Timestamp extension type id
    pub const timestamp_type: i8 = -1;
};
