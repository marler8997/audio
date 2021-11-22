const std = @import("std");
const Builder = std.build.Builder;
const GitRepoStep = @import("GitRepoStep.zig");

pub fn build(b: *Builder) !void {
    const zigwin32_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/marlersoft/zigwin32",
        .branch = "15.0.1-preview",
        .sha = "7685bb92610ba4f34e0077eb2b6263fa6f1f36c5",
    });

    const mode = b.standardReleaseOptions();
    {
        const exe = b.addExecutable("audio", "main.zig");
        exe.setBuildMode(mode);
        exe.install();
        exe.addPackagePath("stdext", "stdext.zig");
        exe.step.dependOn(&zigwin32_repo.step);
        exe.addPackagePath("win32", b.pathJoin(&.{zigwin32_repo.getPath(&exe.step), "win32.zig"}));

        const runCommand = exe.run();
        runCommand.step.dependOn(b.getInstallStep());

        const runStep = b.step("run", "Run the app");
        runStep.dependOn(&runCommand.step);
    }

    {
        const windows_midi = b.addExecutable("windows-midi", "tools" ++ std.fs.path.sep_str ++ "windows-midi.zig");
        windows_midi.setBuildMode(mode);
        windows_midi.install();
        windows_midi.step.dependOn(&zigwin32_repo.step);
        const zigwin32_index_file = b.pathJoin(&.{zigwin32_repo.getPath(&windows_midi.step), "win32.zig"});
        windows_midi.addPackagePath("win32", zigwin32_index_file);
        windows_midi.addPackage(.{
            .name = "audio",
            .path = .{ .path = "audio.zig" },
            .dependencies = &[_]std.build.Pkg{
                std.build.Pkg{ .name = "win32", .path = .{ .path = zigwin32_index_file } },
            }
        });
    }

    {
        const driver = b.addSharedLibrary("windowsmididriver", "drivers" ++ std.fs.path.sep_str ++ "windowsmididriver.zig", .unversioned);
        driver.setBuildMode(mode);
        driver.install();
        driver.step.dependOn(&zigwin32_repo.step);
        const zigwin32_index_file = b.pathJoin(&.{zigwin32_repo.getPath(&driver.step), "win32.zig"});
        driver.addPackagePath("win32", zigwin32_index_file);
        // Just hardcoded for now
        driver.addLibPath("C:\\Program Files (x86)\\Windows Kits\\10\\Lib\\10.0.22000.0\\km\\x64");
        //windows_midi.addPackage(.{
        //    .name = "audio",
        //    .path = .{ .path = "audio.zig" },
        //    .dependencies = &[_]std.build.Pkg{
        //        std.build.Pkg{ .name = "win32", .path = .{ .path = zigwin32_index_file } },
        //    }
        //});
    }
}
