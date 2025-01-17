const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const hermes = b.addModule("hermes", .{ .root_source_file = b.path("src/hermes/hermes.zig") });

    const server = b.addExecutable(.{
        .name = "AthenaDB",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const client = b.addStaticLibrary(.{ .name = "AthenaClient", .root_source_file = b.path("src/client/lib.zig"), .target = target, .optimize = optimize });
    client.root_module.addImport("hermes", hermes);

    server.root_module.addImport("hermes", hermes);
    b.installArtifact(server);
    b.installArtifact(client);

    const run_cmd = b.addRunArtifact(server);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    //tests
    const client_mod = b.addModule("client module", .{ .root_source_file = b.path("src/client/lib.zig") });
    const db_mod = b.addModule("db module", .{ .root_source_file = b.path("src/server/db.zig") });
    client_mod.addImport("hermes", hermes);
    db_mod.addImport("hermes", hermes);

    const integration_tests = b.addTest(.{
        .name = "integration tests",
        .root_source_file = b.path("src/test/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    const hermes_unit_tests = b.addTest(.{
        .name = "module tests",
        .root_source_file = b.path("src/hermes/hermes.zig"),
        .target = target,
        .optimize = optimize,
    });
    const client_unit_tests = b.addTest(.{
        .name = "client tests",
        .root_source_file = b.path("src/client/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    const server_unit_tests = b.addTest(.{
        .name = "server tests",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_unit_tests.root_module.addImport("hermes", hermes);
    server_unit_tests.root_module.addImport("hermes", hermes);
    integration_tests.root_module.addImport("hermes", hermes);
    integration_tests.root_module.addImport("client", client_mod);
    integration_tests.root_module.addImport("db", db_mod);

    const run_server_unit_tests = b.addRunArtifact(server_unit_tests);
    const run_client_unit_tests = b.addRunArtifact(client_unit_tests);
    const run_hermes_unit_tests = b.addRunArtifact(hermes_unit_tests);
    const run_integration_tests = b.addRunArtifact(integration_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_server_unit_tests.step);
    test_step.dependOn(&run_client_unit_tests.step);
    test_step.dependOn(&run_hermes_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);
}
