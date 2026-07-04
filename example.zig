const std = @import("std");

const LsColors = @import("lscolors").LsColors;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var lsc = try LsColors.fromEnv(allocator, init.environ_map);
    defer lsc.deinit();

    var dir = try std.Io.Dir.cwd().openDir(io, ".", .{ .iterate = true });
    defer dir.close(io);

    var iterator = dir.iterate();
    while (try iterator.next(io)) |itm| {
        std.log.info("{f}", .{try lsc.styled(io, itm.name)});
    }
}
