const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("audio", "main.zig");
    exe.setBuildMode(mode);
    exe.install();
    ////exe.linkSystemLibrary("c");

    const runCommand = exe.run();
    runCommand.step.dependOn(b.getInstallStep());

    const runStep = b.step("run", "Run the app");
    runStep.dependOn(&runCommand.step);
}
