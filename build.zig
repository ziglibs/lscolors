const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    var main_tests = b.addTest("src/main.zig");
    main_tests.setTarget(target);
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
