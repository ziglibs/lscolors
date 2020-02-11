# zig-lscolors

[![Build Status](https://travis-ci.org/joachimschmidt557/zig-lscolors.svg?branch=master)](https://travis-ci.org/joachimschmidt557/zig-lscolors)

A zig library for colorizing paths according to LS_COLORS

## Quick Example

```zig
const LsColors = @import("src/main.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var lsc = try LsColors.fromEnv(allocator);
    defer lsc.deinit();

    const style = try lsc.styleForPath("build.zig");
}
```
