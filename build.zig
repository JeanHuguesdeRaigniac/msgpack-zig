const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "msgpack",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    _ = b.addModule("msgpack", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    b.step("test", "Run unit tests").dependOn(&run_tests.step);

    const msgpack_mod = b.createModule(.{ .root_source_file = b.path("src/root.zig") });

    const conf_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/conformance.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    conf_tests.root_module.addImport("msgpack", msgpack_mod);
    b.step("test-conformance", "Run msgpack-test-suite conformance tests")
        .dependOn(&b.addRunArtifact(conf_tests).step);
}
