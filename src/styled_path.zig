const std = @import("std");
const testing = std.testing;

const style = @import("ansi-term/src/style.zig");
const Style = style.Style;
const FontStyle = style.FontStyle;
const Color = style.Color;
const ansi_format = @import("ansi-term/src/format.zig");

const LsColors = @import("main.zig").LsColors;
const PathComponentIterator = @import("path_components.zig").PathComponentIterator;

pub const StyledPath = struct {
    path: []const u8,
    style: Style,

    const Self = @This();

    pub fn format(
        value: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        const sty = value.style;

        try ansi_format.updateStyle(writer, sty, Style{});
        try writer.writeAll(value.path);
        try ansi_format.updateStyle(writer, Style{}, sty);
    }
};

pub const StyledPathComponents = struct {
    path: []const u8,
    lsc: *LsColors,

    const Self = @This();

    pub fn format(
        value: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        var iter = PathComponentIterator.init(value.path);
        var current_style: ?Style = Style{};

        while (iter.next()) |component| {
            const new_style = value.lsc.styleForPath(component.path) catch Style{};
            defer current_style = new_style;

            // Update style
            try ansi_format.updateStyle(writer, new_style, current_style);

            // Actual item name
            try writer.writeAll(component.name);
        }

        try ansi_format.updateStyle(writer, Style{}, current_style);
    }
};

test "format default styled path" {
    const styled_path = StyledPath{
        .path = "/usr/local/bin/zig",
        .style = Style{},
    };

    const allocator = std.testing.allocator;

    const expected = "/usr/local/bin/zig";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{styled_path});
    defer allocator.free(actual);

    testing.expectEqualSlices(u8, expected, actual);
}

test "format bold path" {
    const styled_path = StyledPath{
        .path = "/usr/local/bin/zig",
        .style = Style{
            .font_style = FontStyle.bold,
        },
    };

    const allocator = std.testing.allocator;

    const expected = "\x1B[1m/usr/local/bin/zig\x1B[0m";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{styled_path});
    defer allocator.free(actual);

    testing.expectEqualSlices(u8, expected, actual);
}

test "format bold and italic path" {
    const styled_path = StyledPath{
        .path = "/usr/local/bin/zig",
        .style = Style{
            .font_style = FontStyle{
                .bold = true,
                .italic = true,
            },
        },
    };

    const allocator = std.testing.allocator;

    const expected = "\x1B[1;3m/usr/local/bin/zig\x1B[0m";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{styled_path});
    defer allocator.free(actual);

    testing.expectEqualSlices(u8, expected, actual);
}

test "format colored path" {
    const styled_path = StyledPath{
        .path = "/usr/local/bin/zig",
        .style = Style{
            .foreground = Color.Red,
        },
    };

    const allocator = std.testing.allocator;

    const expected = "\x1B[31m/usr/local/bin/zig\x1B[0m";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{styled_path});
    defer allocator.free(actual);

    testing.expectEqualSlices(u8, expected, actual);
}
