const std = @import("std");
const os = std.os;
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

const ansi_term = @import("ansi_term");
const Style = ansi_term.style.Style;

const EntryType = @import("entry_types.zig").EntryType;
const styled_path = @import("styled_path.zig");
const StyledPath = styled_path.StyledPath;
const StyledPathComponents = styled_path.StyledPathComponents;

const ls_colors_default = "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=00:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arc=01;31:*.arj=01;31:*.taz=01;31:*.lha=01;31:*.lz4=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.tzo=01;31:*.t7z=01;31:*.zip=01;31:*.z=01;31:*.dz=01;31:*.gz=01;31:*.lrz=01;31:*.lz=01;31:*.lzo=01;31:*.xz=01;31:*.zst=01;31:*.tzst=01;31:*.bz2=01;31:*.bz=01;31:*.tbz=01;31:*.tbz2=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.alz=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.cab=01;31:*.wim=01;31:*.swm=01;31:*.dwm=01;31:*.esd=01;31:*.jpg=01;35:*.jpeg=01;35:*.mjpg=01;35:*.mjpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.webm=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=00;36:*.au=00;36:*.flac=00;36:*.m4a=00;36:*.mid=00;36:*.midi=00;36:*.mka=00;36:*.mp3=00;36:*.mpc=00;36:*.ogg=00;36:*.ra=00;36:*.wav=00;36:*.oga=00;36:*.opus=00;36:*.spx=00;36:*.xspf=00;36:";

const EntryTypeMap = [EntryType.len]?Style;

const PatternStyle = struct {
    pattern: []const u8,
    style: Style,
};

fn pathMatchesPattern(path: []const u8, pattern: []const u8) bool {
    if (path.len < 1) return false;
    if (pattern.len < 1) return false;

    return if (pattern[0] == '*') std.mem.endsWith(u8, path, pattern[1..]) else std.mem.eql(u8, path, pattern);
}

test "path matches pattern" {
    try expect(pathMatchesPattern("README", "README"));
    try expect(!pathMatchesPattern("README", "main.zig"));
    try expect(pathMatchesPattern("README.md", "*.md"));
    try expect(!pathMatchesPattern("README", "*.zig"));
}

pub const LsColors = struct {
    allocator: Allocator,
    copied_str: ?[]const u8,
    entry_type_mapping: EntryTypeMap,
    pattern_mapping: std.ArrayListUnmanaged(PatternStyle),
    ln_target: bool,

    const Self = @This();

    /// Parses a LS_COLORS string
    /// Does not take ownership of the string, copies it instead
    pub fn parseStr(allocator: Allocator, s: []const u8) !Self {
        const str_copy = try allocator.dupe(u8, s);
        errdefer allocator.free(str_copy);

        var result = try Self.parseStrOwned(allocator, str_copy);
        result.copied_str = str_copy;

        return result;
    }

    /// Parses a LS_COLORS string
    /// Takes ownership of the string
    pub fn parseStrOwned(allocator: Allocator, s: []const u8) !Self {
        var entry_types = [_]?Style{null} ** EntryType.len;

        var patterns: std.ArrayListUnmanaged(PatternStyle) = .{};
        errdefer patterns.deinit(allocator);

        var ln_target = false;

        var rules_iter = std.mem.splitScalar(u8, s, ':');
        while (rules_iter.next()) |rule| {
            var iter = std.mem.splitScalar(u8, rule, '=');

            if (iter.next()) |pattern| {
                if (iter.next()) |sty| {
                    if (iter.next() != null)
                        continue;

                    if (std.mem.eql(u8, "ln", pattern) and std.mem.eql(u8, "target", sty)) {
                        ln_target = true;
                    } else if (Style.parse(sty)) |style_parsed| {
                        if (EntryType.fromStr(pattern)) |entry_type| {
                            entry_types[@intFromEnum(entry_type)] = style_parsed;
                        } else {
                            try patterns.append(allocator, .{
                                .pattern = pattern,
                                .style = style_parsed,
                            });
                        }
                    }
                }
            }
        }

        return Self{
            .allocator = allocator,
            .copied_str = null,
            .entry_type_mapping = entry_types,
            .pattern_mapping = patterns,
            .ln_target = ln_target,
        };
    }

    /// Parses a default set of LS_COLORS rules
    pub fn default(alloc: Allocator) !Self {
        return Self.parseStr(alloc, ls_colors_default);
    }

    /// Parses the current environment variable `LS_COLORS`
    /// If the environment variable does not exist, falls back
    /// to the default set of LS_COLORS rules
    pub fn fromEnv(alloc: Allocator) !Self {
        if (std.process.getEnvVarOwned(alloc, "LS_COLORS")) |env| {
            return Self.parseStr(alloc, env);
        } else |_| {
            return Self.default(alloc);
        }
    }

    /// Frees all memory allocated when initializing this struct
    pub fn deinit(self: *Self) void {
        // Will only be freed when the string was copied
        if (self.copied_str) |str| {
            self.allocator.free(str);
        }

        self.pattern_mapping.deinit(self.allocator);
    }

    pub const StyleForPathError = error{TooManySymlinks} || std.fs.File.OpenError || std.fs.Dir.ReadLinkError || std.fs.File.ModeError;

    /// Queries the style for this particular path.
    /// Does not take ownership of the path. Requires no allocations.
    pub fn styleForPath(self: Self, initial_path: []const u8) StyleForPathError!Style {
        const max_link_depth = 20;
        var i: usize = 0;

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        var path = initial_path;

        while (i < max_link_depth) : (i += 1) {
            const entry_type = try EntryType.fromPath(path);
            const style_for_type = self.entry_type_mapping[@intFromEnum(entry_type)];

            if (style_for_type) |sty| {
                if (entry_type == .SymbolicLink and self.ln_target) {
                    path = try std.fs.cwd().readLink(path, &path_buf);
                    continue;
                }

                if (entry_type != .Normal and entry_type != .RegularFile) {
                    return sty;
                }
            }

            for (self.pattern_mapping.items) |entry| {
                if (pathMatchesPattern(path, entry.pattern)) {
                    return entry.style;
                }
            }

            return if (style_for_type) |sty| sty else Style{};
        }

        return error.TooManySymlinks;
    }

    /// Creates a styled path struct for easy styled printing.
    /// Does not take ownership of the path. Requires no allocations.
    pub fn styled(self: Self, path: []const u8) StyleForPathError!StyledPath {
        return StyledPath{
            .path = path,
            .style = try self.styleForPath(path),
        };
    }

    /// Returns a StyledPathComponent instance which, when formatted,
    /// nicely stylizes each component (directories and files) of the
    /// path with the respective style
    pub fn styledComponents(self: *Self, path: []const u8) StyledPathComponents {
        return StyledPathComponents{
            .path = path,
            .lsc = self,
        };
    }
};

test "parse empty" {
    const allocator = std.testing.allocator;

    var lsc = try LsColors.parseStr(allocator, "");
    lsc.deinit();
}

test "parse default" {
    const allocator = std.testing.allocator;

    var lsc = try LsColors.default(allocator);
    lsc.deinit();
}

test "parse geoff.greer.fm default lscolors" {
    const allocator = std.testing.allocator;

    var lsc = try LsColors.parseStr(allocator, "di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43");
    defer lsc.deinit();

    const expected = Style{
        .foreground = .Blue,
    };
    try expectEqual(lsc.entry_type_mapping[@intFromEnum(EntryType.Directory)].?, expected);
}

test "get style of cwd from empty" {
    const allocator = std.testing.allocator;

    var lsc = try LsColors.parseStr(allocator, "");
    defer lsc.deinit();

    try expectEqual(Style{}, try lsc.styleForPath("."));
    try expectEqual(Style{}, try lsc.styleForPath(".."));
}

test "get style of cwd from geoff.greer.fm" {
    const allocator = std.testing.allocator;

    var lsc = try LsColors.parseStr(allocator, "di=34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43");
    defer lsc.deinit();

    const expected = Style{
        .foreground = .Blue,
    };
    try expectEqual(expected, try lsc.styleForPath("."));
    try expectEqual(expected, try lsc.styleForPath(".."));
}

test "get styled string from default" {
    const allocator = std.testing.allocator;

    var lsc = try LsColors.default(allocator);
    defer lsc.deinit();

    const expected = "\x1B[1;34m.\x1B[0m";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{try lsc.styled(".")});
    defer allocator.free(actual);

    try expectEqualSlices(u8, expected, actual);
}

test "get styled path components from default (directory)" {
    const allocator = std.testing.allocator;

    var lsc = try LsColors.default(allocator);
    defer lsc.deinit();

    const expected = "\x1B[1;34m.\x1B[0m";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{lsc.styledComponents(".")});
    defer allocator.free(actual);

    try expectEqualSlices(u8, expected, actual);
}

test "get styled path components from default (file)" {
    const allocator = std.testing.allocator;

    var lsc = try LsColors.default(allocator);
    defer lsc.deinit();

    const expected = "\x1B[1;34m./\x1B[0mmain.zig";
    const actual = try std.fmt.allocPrint(allocator, "{}", .{lsc.styledComponents("./main.zig")});
    defer allocator.free(actual);

    try expectEqualSlices(u8, expected, actual);
}
