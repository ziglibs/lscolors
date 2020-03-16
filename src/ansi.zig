const std = @import("std");

const style = @import("style.zig");
const Style = style.Style;
const FontStyle = style.FontStyle;
const Color = style.Color;

pub const Esc = "\x1B";
pub const Csi = Esc ++ "[";

pub const Reset = Csi ++ "0m";

pub const Prefix = struct {
    sty: Style,

    const Self = @This();

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: var) @TypeOf(out_stream).Error!void {
        if (value.sty.isDefault()) return;

        // Start the escape sequence
        try out_stream.writeAll(Csi);
        var written_something = false;

        // Font styles
        if (value.sty.font_style.bold) {
            written_something = true;
            try out_stream.writeAll("1");
        }
        if (value.sty.font_style.italic) {
            if (written_something) {
                try out_stream.writeAll(";");
            } else {
                written_something = true;
            }
            try out_stream.writeAll("3");
        }
        if (value.sty.font_style.underline) {
            if (written_something) {
                try out_stream.writeAll(";");
            } else {
                written_something = true;
            }
            try out_stream.writeAll("4");
        }

        // Foreground color
        if (value.sty.foreground) |clr| {
            if (written_something) {
                try out_stream.writeAll(";");
            } else {
                written_something = true;
            }

            switch (clr) {
                .Black => try out_stream.writeAll("30"),
                .Red => try out_stream.writeAll("31"),
                .Green => try out_stream.writeAll("32"),
                .Yellow => try out_stream.writeAll("33"),
                .Blue => try out_stream.writeAll("34"),
                .Magenta => try out_stream.writeAll("35"),
                .Cyan => try out_stream.writeAll("36"),
                .White => try out_stream.writeAll("37"),
                .Fixed => |fixed| try std.fmt.format(out_stream, "38;5;{}", .{fixed}),
                .RGB => |rgb| try std.fmt.format(out_stream, "38;2;{};{};{}", .{rgb.r, rgb.g, rgb.b}),
            }
        }

        // Background color
        if (value.sty.background) |clr| {
            if (written_something) {
                try out_stream.writeAll(";");
            } else {
                written_something = true;
            }

            switch (clr) {
                .Black => try out_stream.writeAll("40"),
                .Red => try out_stream.writeAll("41"),
                .Green => try out_stream.writeAll("42"),
                .Yellow => try out_stream.writeAll("43"),
                .Blue => try out_stream.writeAll("44"),
                .Magenta => try out_stream.writeAll("45"),
                .Cyan => try out_stream.writeAll("46"),
                .White => try out_stream.writeAll("47"),
                .Fixed => |fixed| try std.fmt.format(out_stream, "48;5;{}", .{fixed}),
                .RGB => |rgb| try std.fmt.format(out_stream, "48;2;{};{};{}", .{rgb.r, rgb.g, rgb.b}),
            }
        }

        // End the escape sequence
        try out_stream.writeAll("m");
    }
};

pub const Postfix = struct {
    sty: Style,

    const Self = @This();

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: var) @TypeOf(out_stream).Error!void {
        if (value.sty.isDefault()) return;

        try out_stream.writeAll(Reset);
    }
};
