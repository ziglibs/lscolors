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
        .name = "lscolors",
        .root_module = module,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = main_tests.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addImport("lscolors", module);

    const run_cmd = b.addRunArtifact(example);

    const run_step = b.step("example", "Run the example");
    run_step.dependOn(&run_cmd.step);
}
