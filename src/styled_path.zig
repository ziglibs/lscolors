const std = @import("std");
const testing = std.testing;

const style = @import("zig-ansi-term/src/style.zig");
const Style = style.Style;
const FontStyle = style.FontStyle;
const Color = style.Color;
const ansi_format = @import("zig-ansi-term/src/format.zig");

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
        const prefix = ansi_format.Prefix{ .sty = sty };
        const postfix = ansi_format.Postfix{ .sty = sty };

        return std.fmt.format(writer, "{}{}{}", .{ prefix, value.path, postfix });
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
        var current_sty = Style.default;

        while (iter.next()) |component| {
            const old_sty = current_sty;
            current_sty = value.lsc.styleForPath(component.path) catch Style.default;

            if (!old_sty.eql(current_sty)) {
                // Emit postfix of previous style
                const postfix = ansi_format.Postfix{ .sty = old_sty };

                // Emit prefix of current style
                const prefix = ansi_format.Prefix{ .sty = current_sty };

                try std.fmt.format(writer, "{}{}", .{ postfix, prefix });
            }

            // Actual item name
            try std.fmt.format(writer, "{}", .{component.name});
        }

        const postfix = ansi_format.Postfix{ .sty = current_sty };
        try std.fmt.format(writer, "{}", .{postfix});
    }
};

test "format default styled path" {
    const styled_path = StyledPath{
        .path = "/usr/local/bin/zig",
        .style = Style.default,
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
            .foreground = null,
            .background = null,
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
            .foreground = null,
            .background = null,
            .font_style = FontStyle{
                .bold = true,
                .italic = true,
                .underline = false,
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
            .background = null,
            .font_style = FontStyle.default,
        },
    };

    const allocator = std.testing.allocator;

    const expected = "\x1B[31m/usr/local/bin/zig\x1B[0m";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{styled_path});
    defer allocator.free(actual);

    testing.expectEqualSlices(u8, expected, actual);
}
