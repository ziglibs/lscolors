# zig-lscolors

[![Build Status](https://travis-ci.org/joachimschmidt557/zig-lscolors.svg?branch=master)](https://travis-ci.org/joachimschmidt557/zig-lscolors)

A zig library for colorizing paths according to LS_COLORS

## Quick Example

```zig
const std = @import("std");

const LsColors = @import("src/main.zig").LsColors;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var lsc = try LsColors.fromEnv(allocator);
    defer lsc.deinit();

    const dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    var iterator = dir.iterate();

    while (try iterator.next()) |itm| {
        std.debug.warn("{}\n", .{lsc.styled(itm.name)});
    }
}
```
