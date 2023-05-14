const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ansi_term = b.dependency("ansi-term", .{}).module("ansi-term");

    const module = b.addModule("lscolors", .{
        .source_file = .{ .path = "src/main.zig" },
        .dependencies = &.{
            .{ .name = "ansi-term", .module = ansi_term },
        },
    });

    const main_tests = b.addTest(.{
        .name = "main test suite",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.addModule("ansi-term", ansi_term);

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{ .path = "example.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("lscolors", module);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("example", "Run the example");
    run_step.dependOn(&run_cmd.step);
}
