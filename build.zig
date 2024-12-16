const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const server_exe = b.addExecutable(.{ .name = "AthenaDBServer", .root_source_file = b.path("src/server/main.zig"), .target = target, .optimize = optimize, .version = .{
        .major = 0,
        .minor = 0,
        .patch = 1,
    } });

    const client_exe = b.addExecutable(.{ .name = "AthenaDBClient", .root_source_file = b.path("src/client/main.zig"), .target = target, .optimize = optimize, .version = .{
        .major = 0,
        .minor = 0,
        .patch = 1,
    } });

    const hermes = b.addModule("hermes", .{ .root_source_file = b.path("src/hermes/hermes.zig") });
    server_exe.root_module.addImport("hermes", hermes);
    client_exe.root_module.addImport("hermes", hermes);

    b.installArtifact(server_exe);

    b.installArtifact(client_exe);

    const run_server_cmd = b.addRunArtifact(server_exe);
    const run_client_cmd = b.addRunArtifact(client_exe);

    run_server_cmd.step.dependOn(b.getInstallStep());
    run_client_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_server_cmd.addArgs(args);
        run_client_cmd.addArgs(args);
    }

    const run_server_step = b.step("run_server", "Run the server");
    const run_client_step = b.step("run_client", "Run the client");

    run_server_step.dependOn(&run_server_cmd.step);
    run_client_step.dependOn(&run_client_cmd.step);

    const server_unit_tests = b.addTest(.{
        .name = "server tests",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const client_unit_tests = b.addTest(.{
        .name = "client tests",
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    server_unit_tests.root_module.addImport("hermes", hermes);
    client_unit_tests.root_module.addImport("hermes", hermes);
    const run_server_unit_tests = b.addRunArtifact(server_unit_tests);
    const run_client_unit_tests = b.addRunArtifact(client_unit_tests);

    const test_server_step = b.step("test_server", "Run server unit tests");
    const test_client_step = b.step("test_client", "Run client unit tests");
    test_server_step.dependOn(&run_server_unit_tests.step);
    test_client_step.dependOn(&run_client_unit_tests.step);

    //create test command for all modules
    const hermes_unit_tests = b.addTest(.{
        .name = "hermes tests",
        .root_source_file = b.path("src/hermes/hermes.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_hermes_unit_tests = b.addRunArtifact(hermes_unit_tests);
    const test_modules_step = b.step("test_modules", "Run module unit tests");
    test_modules_step.dependOn(&run_hermes_unit_tests.step);
}
