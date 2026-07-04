const std = @import("std");
const builtin = @import("builtin");

const StaticStringMap = std.StaticStringMap;
const posix = std.posix;
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

    fn fromPathPosix(io: std.Io, dir: std.Io.Dir, path: []const u8) !Self {
        const stat = try dir.statFile(io, path, .{ .follow_symlinks = false });

        const kind = stat.kind;
        const mode = stat.permissions.toMode();

        if (kind == .block_device) {
            return .BlockDevice;
        } else if (kind == .character_device) {
            return .CharacterDevice;
        } else if (kind == .directory) {
            return .Directory;
        } else if (kind == .named_pipe) {
            return .FIFO;
        } else if (kind == .unix_domain_socket) {
            return .Socket;
        } else if (mode & posix.S.ISUID != 0) {
            return .Setuid;
        } else if (mode & posix.S.ISGID != 0) {
            return .Setgid;
        } else if (mode & posix.S.ISVTX != 0) {
            return .Sticky;
        } else if (kind == .file) {
            if (mode & posix.S.IXUSR != 0) {
                return .ExecutableFile;
            } else if (mode & posix.S.IXGRP != 0) {
                return .ExecutableFile;
            } else if (mode & posix.S.IXOTH != 0) {
                return .ExecutableFile;
            }

            return .RegularFile;
        } else if (kind == .sym_link) {
            var path_buf: [std.fs.max_path_bytes]u8 = undefined;
            const target_len = try std.Io.Dir.cwd().readLink(io, path, &path_buf);

            var target_file = std.Io.Dir.cwd().openFile(io, path_buf[0..target_len], .{}) catch return .OrphanedSymbolicLink;
            target_file.close(io);

            return .SymbolicLink;
        } else {
            return .Normal;
        }
    }

    /// Get the entry type for this path
    /// Does not take ownership of the path
    pub fn fromPath(io: std.Io, dir: std.Io.Dir, path: []const u8) !Self {
        switch (builtin.os.tag) {
            .windows => @compileError("unsupported platform"),
            .wasi => @compileError("unsupported platform"),

            .linux => return try Self.fromPathPosix(io, dir, path),

            else => return try Self.fromPathPosix(io, dir, path),
        }
    }
};

test "entry types" {
    const io = std.testing.io;
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var file_normal = try tmp_dir.dir.createFile(io, "test", .{});
    defer file_normal.close(io);

    var file_executable = try tmp_dir.dir.createFile(io, "test-executable", .{ .permissions = .executable_file });
    defer file_executable.close(io);

    try tmp_dir.dir.createDir(io, "dir", .default_dir);

    try expectEqual(EntryType.fromPath(io, tmp_dir.dir, "test"), .RegularFile);
    try expectEqual(EntryType.fromPath(io, tmp_dir.dir, "test-executable"), .ExecutableFile);
    try expectEqual(EntryType.fromPath(io, tmp_dir.dir, "dir"), .Directory);
}
