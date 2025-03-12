const Build = @import("std").Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ansi_term = b.dependency("ansi_term", .{}).module("ansi_term");

    const module = b.addModule("lscolors", .{
        .root_source_file = b.path("src/main.zig"),
        .imports = &.{
            .{ .name = "ansi_term", .module = ansi_term },
        },
        .target = target,
        .optimize = optimize,
    });

    const main_tests = b.addTest(.{
        .name = "main test suite",
        .root_module = module,
    });
    main_tests.root_module.addImport("ansi_term", ansi_term);

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    const exe = b.addExecutable(.{
        .name = "example",
        .root_module = module,
    });
    exe.root_module.addImport("lscolors", module);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("example", "Run the example");
    run_step.dependOn(&run_cmd.step);
}
