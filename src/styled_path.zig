const std = @import("std");
const testing = std.testing;

const ansi_term = @import("ansi_term");
const style = ansi_term.style;
const Style = style.Style;
const FontStyle = style.FontStyle;
const Color = style.Color;
const ansi_format = ansi_term.format;

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
        _ = fmt;
        _ = options;

        const sty = value.style;

        try ansi_format.updateStyle(writer, sty, .{});
        try writer.writeAll(value.path);
        try ansi_format.updateStyle(writer, .{}, sty);
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
        _ = fmt;
        _ = options;

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

        try ansi_format.updateStyle(writer, .{}, current_style);
    }
};

test "format default styled path" {
    const styled_path: StyledPath = .{
        .path = "/usr/local/bin/zig",
        .style = .{},
    };

    const allocator = std.testing.allocator;

    const expected = "/usr/local/bin/zig";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{styled_path});
    defer allocator.free(actual);

    try testing.expectEqualSlices(u8, expected, actual);
}

test "format bold path" {
    const styled_path: StyledPath = .{
        .path = "/usr/local/bin/zig",
        .style = .{
            .font_style = .{ .bold = true },
        },
    };

    const allocator = std.testing.allocator;

    const expected = "\x1B[1m/usr/local/bin/zig\x1B[0m";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{styled_path});
    defer allocator.free(actual);

    try testing.expectEqualSlices(u8, expected, actual);
}

test "format bold and italic path" {
    const styled_path: StyledPath = .{
        .path = "/usr/local/bin/zig",
        .style = .{
            .font_style = .{
                .bold = true,
                .italic = true,
            },
        },
    };

    const allocator = std.testing.allocator;

    const expected = "\x1B[1;3m/usr/local/bin/zig\x1B[0m";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{styled_path});
    defer allocator.free(actual);

    try testing.expectEqualSlices(u8, expected, actual);
}

test "format colored path" {
    const styled_path = StyledPath{
        .path = "/usr/local/bin/zig",
        .style = .{
            .foreground = .Red,
        },
    };

    const allocator = std.testing.allocator;

    const expected = "\x1B[31m/usr/local/bin/zig\x1B[0m";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{styled_path});
    defer allocator.free(actual);

    try testing.expectEqualSlices(u8, expected, actual);
}
