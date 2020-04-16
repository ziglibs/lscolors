const std = @import("std");
const os = std.os;
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

    const NamedEntryType = struct {
        name: []const u8,
        typ: Self,
    };

    const str_type_map = [_]NamedEntryType{
        .{ .name = "no", .typ = .Normal },
        .{ .name = "fi", .typ = .RegularFile },
        .{ .name = "di", .typ = .Directory },
        .{ .name = "ln", .typ = .SymbolicLink },
        .{ .name = "pi", .typ = .FIFO },
        .{ .name = "so", .typ = .Socket },
        .{ .name = "do", .typ = .Door },
        .{ .name = "bd", .typ = .BlockDevice },
        .{ .name = "cd", .typ = .CharacterDevice },
        .{ .name = "or", .typ = .OrphanedSymbolicLink },
        .{ .name = "su", .typ = .Setuid },
        .{ .name = "sg", .typ = .Setgid },
        .{ .name = "st", .typ = .Sticky },
        .{ .name = "ow", .typ = .OtherWritable },
        .{ .name = "tw", .typ = .StickyAndOtherWritable },
        .{ .name = "ex", .typ = .ExecutableFile },
        .{ .name = "mi", .typ = .MissingFile },
        .{ .name = "ca", .typ = .Capabilities },
        .{ .name = "mh", .typ = .MultipleHardLinks },
        .{ .name = "lc", .typ = .LeftCode },
        .{ .name = "rc", .typ = .RightCode },
        .{ .name = "ec", .typ = .EndCode },
        .{ .name = "rs", .typ = .Reset },
        .{ .name = "cl", .typ = .ClearLine },
    };

    pub fn fromStr(entry_type: []const u8) ?Self {
        for (str_type_map) |itm| {
            if (std.mem.eql(u8, entry_type, itm.name)) {
                return itm.typ;
            }
        }
        return null;
    }

    /// Get the entry type for this path
    /// Does not take ownership of the path
    pub fn fromPath(path: []const u8) !Self {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const mode = @intCast(u32, try file.mode());

        if (os.S_ISBLK(mode)) {
            return EntryType.BlockDevice;
        } else if (os.S_ISCHR(mode)) {
            return EntryType.CharacterDevice;
        } else if (os.S_ISDIR(mode)) {
            return EntryType.Directory;
        } else if (os.S_ISFIFO(mode)) {
            return EntryType.FIFO;
        } else if (os.S_ISSOCK(mode)) {
            return EntryType.Socket;
        } else if (mode & os.S_ISUID != 0) {
            return EntryType.Setuid;
        } else if (mode & os.S_ISGID != 0) {
            return EntryType.Setgid;
        } else if (mode & os.S_ISVTX != 0) {
            return EntryType.Sticky;
        } else if (os.S_ISREG(mode)) {
            if (mode & os.S_IXUSR != 0) {
                return EntryType.ExecutableFile;
            } else if (mode & os.S_IXGRP != 0) {
                return EntryType.ExecutableFile;
            } else if (mode & os.S_IXOTH != 0) {
                return EntryType.ExecutableFile;
            }

            return EntryType.RegularFile;
        } else if (os.S_ISLNK(mode)) {
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
    expectEqual(EntryType.fromStr(""), null);
}

test "entry type of . and .." {
    expectEqual(EntryType.fromPath("."), .Directory);
    expectEqual(EntryType.fromPath(".."), .Directory);
}

test "entry type of /dev/null" {
    expectEqual(EntryType.fromPath("/dev/null"), .CharacterDevice);
}

test "entry type of /bin/sh" {
    expectEqual(EntryType.fromPath("/bin/sh"), .ExecutableFile);
}
