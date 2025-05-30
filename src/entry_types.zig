const std = @import("std");
const builtin = @import("builtin");

const os = std.os;
const posix = std.posix;
const StaticStringMap = std.StaticStringMap;
const File = std.fs.File;
const expectEqual = std.testing.expectEqual;

pub const EntryType = enum {
    /// `no`: Normal (non-filename) text
    Normal,

    /// `fi`: Regular file
    RegularFile,

    /// `di`: Directory
    Directory,

    /// `ln`: Symbolic link
    SymbolicLink,

    /// `pi`: Named pipe or FIFO
    FIFO,

    /// `so`: Socket
    Socket,

    /// `do`: Door (IPC connection to another program)
    Door,

    /// `bd`: Block-oriented device
    BlockDevice,

    /// `cd`: Character-oriented device
    CharacterDevice,

    /// `or`: A broken symbolic link
    OrphanedSymbolicLink,

    /// `su`: A file that is setuid (`u+s`)
    Setuid,

    /// `sg`: A file that is setgid (`g+s`)
    Setgid,

    /// `st`: A directory that is sticky and other-writable (`+t`, `o+w`)
    Sticky,

    /// `ow`: A directory that is not sticky and other-writeable (`o+w`)
    OtherWritable,

    /// `tw`: A directory that is sticky and other-writable (`+t`, `o+w`)
    StickyAndOtherWritable,

    /// `ex`: Executable file
    ExecutableFile,

    /// `mi`: Missing file
    MissingFile,

    /// `ca`: File with capabilities set
    Capabilities,

    /// `mh`: File with multiple hard links
    MultipleHardLinks,

    /// `lc`: Code that is printed before the color sequence
    LeftCode,

    /// `rc`: Code that is printed after the color sequence
    RightCode,

    /// `ec`: End code
    EndCode,

    /// `rs`: Code to reset to ordinary colors
    Reset,

    /// `cl`: Code to clear to the end of the line
    ClearLine,

    const Self = @This();

    const str_type_map = StaticStringMap(Self).initComptime(.{
        .{ "no", .Normal },
        .{ "fi", .RegularFile },
        .{ "di", .Directory },
        .{ "ln", .SymbolicLink },
        .{ "pi", .FIFO },
        .{ "so", .Socket },
        .{ "do", .Door },
        .{ "bd", .BlockDevice },
        .{ "cd", .CharacterDevice },
        .{ "or", .OrphanedSymbolicLink },
        .{ "su", .Setuid },
        .{ "sg", .Setgid },
        .{ "st", .Sticky },
        .{ "ow", .OtherWritable },
        .{ "tw", .StickyAndOtherWritable },
        .{ "ex", .ExecutableFile },
        .{ "mi", .MissingFile },
        .{ "ca", .Capabilities },
        .{ "mh", .MultipleHardLinks },
        .{ "lc", .LeftCode },
        .{ "rc", .RightCode },
        .{ "ec", .EndCode },
        .{ "rs", .Reset },
        .{ "cl", .ClearLine },
    });

    pub fn fromStr(entry_type: []const u8) ?Self {
        return str_type_map.get(entry_type);
    }

    fn fromPathPosix(dir: std.fs.Dir, path: []const u8) !Self {
        const flags = std.posix.AT.SYMLINK_NOFOLLOW;
        const stat = try std.posix.fstatat(dir.fd, path, flags);

        const mode = stat.mode;

        if (posix.S.ISBLK(mode)) {
            return .BlockDevice;
        } else if (posix.S.ISCHR(mode)) {
            return .CharacterDevice;
        } else if (posix.S.ISDIR(mode)) {
            return .Directory;
        } else if (posix.S.ISFIFO(mode)) {
            return .FIFO;
        } else if (posix.S.ISSOCK(mode)) {
            return .Socket;
        } else if (mode & posix.S.ISUID != 0) {
            return .Setuid;
        } else if (mode & posix.S.ISGID != 0) {
            return .Setgid;
        } else if (mode & posix.S.ISVTX != 0) {
            return .Sticky;
        } else if (posix.S.ISREG(mode)) {
            if (mode & posix.S.IXUSR != 0) {
                return .ExecutableFile;
            } else if (mode & posix.S.IXGRP != 0) {
                return .ExecutableFile;
            } else if (mode & posix.S.IXOTH != 0) {
                return .ExecutableFile;
            }

            return .RegularFile;
        } else if (posix.S.ISLNK(mode)) {
            var path_buf: [std.fs.max_path_bytes]u8 = undefined;
            const target = try std.fs.cwd().readLink(path, &path_buf);

            var target_file = std.fs.cwd().openFile(target, .{}) catch return EntryType.OrphanedSymbolicLink;
            target_file.close();

            return .SymbolicLink;
        } else {
            return .Normal;
        }
    }

    /// Get the entry type for this path
    /// Does not take ownership of the path
    pub fn fromPath(dir: std.fs.Dir, path: []const u8) !Self {
        switch (builtin.os.tag) {
            .windows => @compileError("unsupported platform"),
            .wasi => @compileError("unsupported platform"),

            .linux => return try Self.fromPathPosix(dir, path),

            else => return try Self.fromPathPosix(dir, path),
        }
    }
};

test "entry types" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var file_normal = try tmp_dir.dir.createFile("test", .{});
    defer file_normal.close();

    var file_executable = try tmp_dir.dir.createFile("test-executable", .{ .mode = 0o777 });
    defer file_executable.close();

    try tmp_dir.dir.makeDir("dir");

    try expectEqual(EntryType.fromPath(tmp_dir.dir, "test"), .RegularFile);
    try expectEqual(EntryType.fromPath(tmp_dir.dir, "test-executable"), .ExecutableFile);
    try expectEqual(EntryType.fromPath(tmp_dir.dir, "dir"), .Directory);
}
