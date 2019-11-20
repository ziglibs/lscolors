const std = @import("std");
const assert = std.debug.assert;

pub const ColorRGB = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const Color = union(enum) {
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
    Fixed: u8,
    RGB: ColorRGB,
};

pub const FontStyle = struct {
    bold: bool,
    italic: bool,
    underline: bool,

    const Self = @This();

    pub fn default() Self {
        return Self {
            .bold = false,
            .italic = false,
            .underline = false,
        };
    }

    pub fn bold() Self {
        return Self {
            .bold = true,
            .italic = false,
            .underline = false,
        };
    }

    pub fn italic() Self {
        return Self {
            .bold = false,
            .italic = true,
            .underline = false,
        };
    }

    pub fn underline() Self {
        return Self {
            .bold = false,
            .italic = false,
            .underline = true,
        };
    }

};

const ParseState = enum {
    Parse8,
    ParseFgNon8,
    ParseFg256,
    ParseFgRed,
    ParseFgGreen,
    ParseFgBlue,
    ParseBgNon8,
    ParseBg256,
    ParseBgRed,
    ParseBgGreen,
    ParseBgBlue,
};

pub const Style = struct {
    foreground: ?Color,
    background: ?Color,
    font_style: FontStyle,

    const Self = @This();

    pub fn fromAnsiSequence(alloc: *std.mem.Allocator, code: []const u8) !?Self {
        if (code.len == 0 or std.mem.eql(u8, code, "0") or std.mem.eql(u8, code, "00")) {
            return null;
        }

        var parts = std.ArrayList(u8).init(alloc);
        var iter = std.mem.separate(code, ";");

        while (iter.next()) |part| {
            const value = std.fmt.parseInt(u8, part, 10) catch return null;
            try parts.append(value);
        }

        var font_style = FontStyle.default();
        var foreground: ?Color = null;
        var background: ?Color = null;

        var state = ParseState.Parse8;
        var red: u8 = 0;
        var green: u8 = 0;

        for (parts.toSlice()) |part| {
            switch(state) {
                .Parse8 => {
                    switch(part) {
                        0 => font_style = FontStyle.default(),
                        1 => font_style.bold = true,
                        3 => font_style.italic = true,
                        4 => font_style.underline = true,
                        30 => foreground = Color.Black,
                        31 => foreground = Color.Red,
                        32 => foreground = Color.Green,
                        33 => foreground = Color.Yellow,
                        34 => foreground = Color.Blue,
                        35 => foreground = Color.Magenta,
                        36 => foreground = Color.Cyan,
                        37 => foreground = Color.White,
                        38 => state = ParseState.ParseFgNon8,
                        39 => foreground = null,
                        40 => background = Color.Black,
                        41 => background = Color.Red,
                        42 => background = Color.Green,
                        43 => background = Color.Yellow,
                        44 => background = Color.Blue,
                        45 => background = Color.Magenta,
                        46 => background = Color.Cyan,
                        47 => background = Color.White,
                        48 => state = ParseState.ParseBgNon8,
                        49 => background = null,
                        else => { return null; },
                    }
                },
                .ParseFgNon8 => {
                    switch(part) {
                        5 => state = ParseState.ParseFg256,
                        2 => state = ParseState.ParseFgRed,
                        else => { return null; },
                    }
                },
                .ParseFg256 => {
                    foreground = Color{ .Fixed = part };
                    state = ParseState.Parse8;
                },
                .ParseFgRed => {
                    red = part;
                    state = ParseState.ParseFgGreen;
                },
                .ParseFgGreen => {
                    green = part;
                    state = ParseState.ParseFgBlue;
                },
                .ParseFgBlue => {
                    foreground = Color{ .RGB = ColorRGB{
                        .r = red,
                        .g = green,
                        .b = part,
                    } };
                    state = ParseState.Parse8;
                },
                .ParseBgNon8 => {
                    switch(part) {
                        5 => state = ParseState.ParseBg256,
                        2 => state = ParseState.ParseBgRed,
                        else => { return null; },
                    }
                },
                .ParseBg256 => {
                    background = Color{ .Fixed = part };
                    state = ParseState.Parse8;
                },
                .ParseBgRed => {
                    red = part;
                    state = ParseState.ParseBgGreen;
                },
                .ParseBgGreen => {
                    green = part;
                    state = ParseState.ParseBgBlue;
                },
                .ParseBgBlue => {
                    background = Color{ .RGB = ColorRGB{
                        .r = red,
                        .g = green,
                        .b = part,
                    } };
                    state = ParseState.Parse8;
                },
            }
        }

        if (state != ParseState.Parse8)
            return null;

        return Self {
            .foreground = foreground,
            .background = background,
            .font_style = font_style,
        };
    }
};

test "parse empty style" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    assert((try Style.fromAnsiSequence(allocator, "")) == null);
    assert((try Style.fromAnsiSequence(allocator, "0")) == null);
    assert((try Style.fromAnsiSequence(allocator, "00")) == null);
}

test "parse bold style" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const style = try Style.fromAnsiSequence(allocator, "01");
    assert(style.?.foreground == null);
    assert(style.?.background == null);
    assert(style.?.font_style.bold == true);
}

test "parse yellow style" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const style = try Style.fromAnsiSequence(allocator, "33");
    assert(style.?.foreground.? == Color.Yellow);
    assert(style.?.background == null);
    assert(style.?.font_style.bold == false);
    assert(style.?.font_style.italic == false);
    assert(style.?.font_style.underline == false);
}

test "parse some fixed color" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const style = try Style.fromAnsiSequence(allocator, "38;5;220;1");
    assert(style.?.foreground.?.Fixed == 220 );
    assert(style.?.background == null);
    assert(style.?.font_style.bold == true);
    assert(style.?.font_style.italic == false);
    assert(style.?.font_style.underline == false);
}

test "parse some rgb color" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const style = try Style.fromAnsiSequence(allocator, "38;2;123;123;123;1");
    assert(style.?.foreground.?.RGB.r == 123);
    assert(style.?.foreground.?.RGB.b == 123);
    assert(style.?.foreground.?.RGB.g == 123);
    assert(style.?.background == null);
    assert(style.?.font_style.bold == true);
    assert(style.?.font_style.italic == false);
    assert(style.?.font_style.underline == false);
}

test "parse wrong rgb color" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const style = try Style.fromAnsiSequence(allocator, "38;2;123");
    assert(style == null);
}
