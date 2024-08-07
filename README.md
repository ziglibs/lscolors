# lscolors

![CI](https://github.com/ziglibs/zig-lscolors/workflows/CI/badge.svg)

A zig library for colorizing paths according to the `LS_COLORS`
environment variable. Designed to work with Zig 0.13.0.

## Quick Example

```zig
const std = @import("std");

const LsColors = @import("lscolors").LsColors;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var lsc = try LsColors.fromEnv(allocator);
    defer lsc.deinit();

    var dir = try std.fs.cwd().openIterableDir(".", .{});
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |itm| {
        std.log.info("{}", .{try lsc.styled(itm.name)});
    }
}
```
