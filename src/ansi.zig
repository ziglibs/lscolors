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

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, comptime output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        if (value.sty.isDefault()) return;

        // Start the escape sequence
        try output(context, Csi);
        var written_something = false;

        // Font styles
        if (value.sty.font_style.bold) {
            written_something = true;
            try output(context, "1");
        }
        if (value.sty.font_style.italic) {
            if (written_something) {
                try output(context, ";");
            } else {
                written_something = true;
            }
            try output(context, "3");
        }
        if (value.sty.font_style.underline) {
            if (written_something) {
                try output(context, ";");
            } else {
                written_something = true;
            }
            try output(context, "4");
        }

        // Foreground color
        if (value.sty.foreground) |clr| {
            if (written_something) {
                try output(context, ";");
            } else {
                written_something = true;
            }

            switch (clr) {
                .Black => try output(context, "30"),
                .Red => try output(context, "31"),
                .Green => try output(context, "32"),
                .Yellow => try output(context, "33"),
                .Blue => try output(context, "34"),
                .Magenta => try output(context, "35"),
                .Cyan => try output(context, "36"),
                .White => try output(context, "37"),
                .Fixed => |fixed| try std.fmt.format(context, Errors, output, "38;5;{}", .{fixed}),
                .RGB => |rgb| try std.fmt.format(context, Errors, output, "38;2;{};{};{}", .{rgb.r, rgb.g, rgb.b}),
            }
        }

        // Background color
        if (value.sty.background) |clr| {
            if (written_something) {
                try output(context, ";");
            } else {
                written_something = true;
            }

            switch (clr) {
                .Black => try output(context, "40"),
                .Red => try output(context, "41"),
                .Green => try output(context, "42"),
                .Yellow => try output(context, "43"),
                .Blue => try output(context, "44"),
                .Magenta => try output(context, "45"),
                .Cyan => try output(context, "46"),
                .White => try output(context, "47"),
                .Fixed => |fixed| try std.fmt.format(context, Errors, output, "48;5;{}", .{fixed}),
                .RGB => |rgb| try std.fmt.format(context, Errors, output, "48;2;{};{};{}", .{rgb.r, rgb.g, rgb.b}),
            }
        }

        // End the escape sequence
        try output(context, "m");
    }
};

pub const Postfix = struct {
    sty: Style,

    const Self = @This();

    pub fn format(value: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, context: var, comptime Errors: type, comptime output: fn (@TypeOf(context), []const u8) Errors!void) Errors!void {
        if (value.sty.isDefault()) return;

        try output(context, Reset);
    }
};
