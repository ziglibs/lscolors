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

    pub fn fromStr(entry_type: []const u8) ?Self {
        if (std.mem.eql(u8, entry_type, "no")) {
            return EntryType.Normal;
        } else if (std.mem.eql(u8, entry_type, "fi")) {
            return EntryType.RegularFile;
        } else if (std.mem.eql(u8, entry_type, "di")) {
            return EntryType.Directory;
        } else if (std.mem.eql(u8, entry_type, "ln")) {
            return EntryType.SymbolicLink;
        } else if (std.mem.eql(u8, entry_type, "pi")) {
            return EntryType.FIFO;
        } else if (std.mem.eql(u8, entry_type, "so")) {
            return EntryType.Socket;
        } else if (std.mem.eql(u8, entry_type, "do")) {
            return EntryType.Door;
        } else if (std.mem.eql(u8, entry_type, "bd")) {
            return EntryType.BlockDevice;
        } else if (std.mem.eql(u8, entry_type, "cd")) {
            return EntryType.CharacterDevice;
        } else if (std.mem.eql(u8, entry_type, "or")) {
            return EntryType.OrphanedSymbolicLink;
        } else if (std.mem.eql(u8, entry_type, "su")) {
            return EntryType.Setuid;
        } else if (std.mem.eql(u8, entry_type, "sg")) {
            return EntryType.Setgid;
        } else if (std.mem.eql(u8, entry_type, "st")) {
            return EntryType.Sticky;
        } else if (std.mem.eql(u8, entry_type, "ow")) {
            return EntryType.OtherWritable;
        } else if (std.mem.eql(u8, entry_type, "tw")) {
            return EntryType.StickyAndOtherWritable;
        } else if (std.mem.eql(u8, entry_type, "ex")) {
            return EntryType.ExecutableFile;
        } else if (std.mem.eql(u8, entry_type, "mi")) {
            return EntryType.MissingFile;
        } else if (std.mem.eql(u8, entry_type, "ca")) {
            return EntryType.Capabilities;
        } else if (std.mem.eql(u8, entry_type, "mh")) {
            return EntryType.MultipleHardLinks;
        } else if (std.mem.eql(u8, entry_type, "lc")) {
            return EntryType.LeftCode;
        } else if (std.mem.eql(u8, entry_type, "rc")) {
            return EntryType.RightCode;
        } else if (std.mem.eql(u8, entry_type, "ec")) {
            return EntryType.EndCode;
        } else if (std.mem.eql(u8, entry_type, "rs")) {
            return EntryType.Reset;
        } else if (std.mem.eql(u8, entry_type, "cl")) {
            return EntryType.ClearLine;
        } else {
            return null;
        }
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
