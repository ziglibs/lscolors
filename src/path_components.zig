const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

pub const PathComponent = struct {
    name: []const u8,
    path: []const u8,
};

pub const PathComponentIterator = struct {
    path: []const u8,
    i: usize,

    const Self = @This();

    /// Initialize a path component iterator
    pub fn init(path: []const u8) Self {
        return Self{
            .path = path,
            .i = 0,
        };
    }

    /// Returns the next path component
    pub fn next(self: *Self) ?PathComponent {
        if (self.i < self.path.len) {
            const old_i = self.i;

            while (self.i < self.path.len) : (self.i += 1) {
                if (std.fs.path.isSep(self.path[self.i])) {
                    break;
                }
            }

            // Add trailing path separator
            if (self.i < self.path.len) {
                self.i += 1;
            }

            return PathComponent{
                .name = self.path[old_i..self.i],
                .path = self.path[0..self.i],
            };
        } else {
            return null;
        }
    }
};

test "path components in absolute path" {
    var path = "/usr/local/bin/zig";
    var iter = PathComponentIterator.init(path[0..]);
    var result: PathComponent = undefined;

    result = iter.next().?;
    expectEqualSlices(u8, "/", result.path);
    expectEqualSlices(u8, "/", result.name);

    result = iter.next().?;
    expectEqualSlices(u8, "/usr/", result.path);
    expectEqualSlices(u8, "usr/", result.name);

    result = iter.next().?;
    expectEqualSlices(u8, "/usr/local/", result.path);
    expectEqualSlices(u8, "local/", result.name);

    result = iter.next().?;
    expectEqualSlices(u8, "/usr/local/bin/", result.path);
    expectEqualSlices(u8, "bin/", result.name);

    result = iter.next().?;
    expectEqualSlices(u8, "/usr/local/bin/zig", result.path);
    expectEqualSlices(u8, "zig", result.name);

    expectEqual(@as(?PathComponent, null), iter.next());
}
