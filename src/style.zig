const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub const ColorRGB = struct {
    r: u8,
    g: u8,
    b: u8,

    const Self = @This();

    pub fn eql(self: Self, other: Self) bool {
        return self.r == other.r and
            self.g == other.g and
            self.b == other.b;
    }
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

    const Self = @This();

    pub fn eql(self: Self, other: Self) bool {
        return switch (self) {
            .Black => other == .Black,
            .Red => other == .Red,
            .Green => other == .Green,
            .Yellow => other == .Yellow,
            .Blue => other == .Blue,
            .Magenta => other == .Magenta,
            .Cyan => other == .Cyan,
            .White => other == .White,
            .Fixed => |x| switch (other) {
                .Fixed => |y| x == y,
                else => false,
            },
            .RGB => |x| switch (other) {
                .RGB => |y| x.eql(y),
                else => false,
            },
        };
    }
};

pub const FontStyle = struct {
    bold: bool,
    italic: bool,
    underline: bool,

    const Self = @This();

    pub const default = Self{
        .bold = false,
        .italic = false,
        .underline = false,
    };

    pub const bold = Self{
        .bold = true,
        .italic = false,
        .underline = false,
    };

    pub const italic = Self{
        .bold = false,
        .italic = true,
        .underline = false,
    };

    pub const underline = Self{
        .bold = false,
        .italic = false,
        .underline = true,
    };

    pub fn isDefault(self: Self) bool {
        return !self.bold and !self.italic and !self.underline;
    }

    pub fn eql(self: Self, other: Self) bool {
        return self.bold == other.bold and
            self.italic == other.italic and
            self.underline == other.underline;
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

    pub const default = Self{
        .foreground = null,
        .background = null,
        .font_style = FontStyle.default,
    };

    pub fn eql(self: Self, other: Self) bool {
        if (self.foreground) |x| {
            if (other.foreground) |y| {
                if (!x.eql(y)) return false;
            } else {
                return false;
            }
        } else {
            if (other.foreground) |_| return false;
        }

        if (self.background) |x| {
            if (other.background) |y| {
                if (!x.eql(y)) return false;
            } else {
                return false;
            }
        } else {
            if (other.background) |_| return false;
        }

        return self.font_style.eql(other.font_style);
    }

    pub fn isDefault(self: Self) bool {
        return self.foreground == null and self.background == null and self.font_style.isDefault();
    }

    pub fn fromAnsiSequence(code: []const u8) ?Self {
        if (code.len == 0 or std.mem.eql(u8, code, "0") or std.mem.eql(u8, code, "00")) {
            return null;
        }

        var font_style = FontStyle.default;
        var foreground: ?Color = null;
        var background: ?Color = null;

        var state = ParseState.Parse8;
        var red: u8 = 0;
        var green: u8 = 0;

        var iter = std.mem.split(code, ";");
        while (iter.next()) |str| {
            const part = std.fmt.parseInt(u8, str, 10) catch return null;

            switch (state) {
                .Parse8 => {
                    switch (part) {
                        0 => font_style = FontStyle.default,
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
                        else => {
                            return null;
                        },
                    }
                },
                .ParseFgNon8 => {
                    switch (part) {
                        5 => state = ParseState.ParseFg256,
                        2 => state = ParseState.ParseFgRed,
                        else => {
                            return null;
                        },
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
                    foreground = Color{
                        .RGB = ColorRGB{
                            .r = red,
                            .g = green,
                            .b = part,
                        },
                    };
                    state = ParseState.Parse8;
                },
                .ParseBgNon8 => {
                    switch (part) {
                        5 => state = ParseState.ParseBg256,
                        2 => state = ParseState.ParseBgRed,
                        else => {
                            return null;
                        },
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
                    background = Color{
                        .RGB = ColorRGB{
                            .r = red,
                            .g = green,
                            .b = part,
                        },
                    };
                    state = ParseState.Parse8;
                },
            }
        }

        if (state != ParseState.Parse8)
            return null;

        return Self{
            .foreground = foreground,
            .background = background,
            .font_style = font_style,
        };
    }
};

test "style equality" {
    const a = Style.default;
    const b = Style{
        .foreground = null,
        .background = null,
        .font_style = FontStyle.bold,
    };
    const c = Style{
        .foreground = Color.Red,
        .background = null,
        .font_style = FontStyle.default,
    };

    expect(a.eql(a));
    expect(b.eql(b));
    expect(c.eql(c));

    expect(!a.eql(b));
    expect(!b.eql(a));
    expect(!a.eql(c));
}

test "parse empty style" {
    expectEqual(@as(?Style, null), Style.fromAnsiSequence(""));
    expectEqual(@as(?Style, null), Style.fromAnsiSequence("0"));
    expectEqual(@as(?Style, null), Style.fromAnsiSequence("00"));
}

test "parse bold style" {
    const style = Style.fromAnsiSequence("01");
    const expected = Style{
        .foreground = null,
        .background = null,
        .font_style = FontStyle.bold,
    };

    expectEqual(@as(?Style, expected), style);
}

test "parse yellow style" {
    const style = Style.fromAnsiSequence("33");
    const expected = Style{
        .foreground = Color.Yellow,
        .background = null,
        .font_style = FontStyle.default,
    };

    expectEqual(@as(?Style, expected), style);
}

test "parse some fixed color" {
    const style = Style.fromAnsiSequence("38;5;220;1");
    const expected = Style{
        .foreground = Color{ .Fixed = 220 },
        .background = null,
        .font_style = FontStyle.bold,
    };

    expectEqual(@as(?Style, expected), style);
}

test "parse some rgb color" {
    const style = Style.fromAnsiSequence("38;2;123;123;123;1");
    const expected = Style{
        .foreground = Color{ .RGB = ColorRGB{ .r = 123, .g = 123, .b = 123 } },
        .background = null,
        .font_style = FontStyle.bold,
    };

    expectEqual(@as(?Style, expected), style);
}

test "parse wrong rgb color" {
    const style = Style.fromAnsiSequence("38;2;123");
    expectEqual(@as(?Style, null), style);
}
