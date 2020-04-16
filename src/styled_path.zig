const std = @import("std");
const testing = std.testing;

const style = @import("style.zig");
const Style = style.Style;
const FontStyle = style.FontStyle;
const Color = style.Color;

const ansi = @import("ansi.zig");

pub const StyledPath = struct {
    path: []const u8,
    style: Style,

    const Self = @This();

    pub fn format(
        value: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: var,
    ) @TypeOf(out_stream).Error!void {
        const sty = value.style;
        const prefix = ansi.Prefix{ .sty = sty };
        const postfix = ansi.Postfix{ .sty = sty };

        return std.fmt.format(out_stream, "{}{}{}", .{ prefix, value.path, postfix });
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
