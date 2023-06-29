const std = @import("std");
const os = std.os;
const ComptimeStringMap = std.ComptimeStringMap;
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

    pub const len = std.meta.fields(Self).len;

    const str_type_map = ComptimeStringMap(Self, .{
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

    /// Get the entry type for this path
    /// Does not take ownership of the path
    pub fn fromPath(path: []const u8) !Self {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const mode = @as(u32, @intCast(try file.mode()));

        if (os.S.ISBLK(mode)) {
            return EntryType.BlockDevice;
        } else if (os.S.ISCHR(mode)) {
            return EntryType.CharacterDevice;
        } else if (os.S.ISDIR(mode)) {
            return EntryType.Directory;
        } else if (os.S.ISFIFO(mode)) {
            return EntryType.FIFO;
        } else if (os.S.ISSOCK(mode)) {
            return EntryType.Socket;
        } else if (mode & os.S.ISUID != 0) {
            return EntryType.Setuid;
        } else if (mode & os.S.ISGID != 0) {
            return EntryType.Setgid;
        } else if (mode & os.S.ISVTX != 0) {
            return EntryType.Sticky;
        } else if (os.S.ISREG(mode)) {
            if (mode & os.S.IXUSR != 0) {
                return EntryType.ExecutableFile;
            } else if (mode & os.S.IXGRP != 0) {
                return EntryType.ExecutableFile;
            } else if (mode & os.S.IXOTH != 0) {
                return EntryType.ExecutableFile;
            }

            return EntryType.RegularFile;
        } else if (os.S.ISLNK(mode)) {
            var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
            const target = try os.readlink(path, &path_buf);

            var target_file = std.fs.cwd().openFile(target, .{}) catch return EntryType.OrphanedSymbolicLink;
            target_file.close();

            return EntryType.SymbolicLink;
        } else {
            return EntryType.Normal;
        }
    }
};

test "parse entry types" {
    try expectEqual(EntryType.fromStr(""), null);
}

test "entry type of . and .." {
    try expectEqual(EntryType.fromPath("."), .Directory);
    try expectEqual(EntryType.fromPath(".."), .Directory);
}

test "entry type of /dev/null" {
    try expectEqual(EntryType.fromPath("/dev/null"), .CharacterDevice);
}

test "entry type of /bin/sh" {
    try expectEqual(EntryType.fromPath("/bin/sh"), .ExecutableFile);
}
