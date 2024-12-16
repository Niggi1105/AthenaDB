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

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
