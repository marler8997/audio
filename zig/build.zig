const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("audio", "main.zig");
    exe.setBuildMode(mode);
    exe.install();
    ////exe.linkSystemLibrary("c");


    const windows_midi = b.addExecutable("windows-midi", "tools" ++ std.fs.path.sep_str ++ "windows-midi.zig");
    windows_midi.setBuildMode(mode);
    windows_midi.install();
    windows_midi.addPackagePath("stdext", "stdext.zig");

    const runCommand = exe.run();
    runCommand.step.dependOn(b.getInstallStep());

    const runStep = b.step("run", "Run the app");
    runStep.dependOn(&runCommand.step);
}
