const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zin_dep = b.dependency("zin", .{});
    const zin_mod = zin_dep.module("zin");

    {
        const exe = b.addExecutable(.{
            .name = "audio",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zin", .module = zin_mod },
                },
            }),
            .win32_manifest = b.path("src/win32dpiaware.manifest"),
        });
        // exe.addWin32ResourceFile(.{ .file = b.path("src/win32.rc") });
        if (target.result.os.tag == .windows) {
            exe.root_module.addImport(
                "win32",
                zin_dep.builder.dependency("win32", .{}).module("win32"),
            );
        }

        const install = b.addInstallArtifact(exe, .{});
        b.step("install-audio", "").dependOn(&install.step);

        const run = b.addRunArtifact(exe);
        b.step("run", "").dependOn(&run.step);
    }
}
