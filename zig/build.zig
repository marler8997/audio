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
        const midilogger = b.addExecutable("midilogger", "tools" ++ std.fs.path.sep_str ++ "midilogger.zig");
        midilogger.setBuildMode(mode);
        midilogger.step.dependOn(&zigwin32_repo.step);
        const zigwin32_index_file = b.pathJoin(&.{zigwin32_repo.getPath(&midilogger.step), "win32.zig"});
        midilogger.addPackagePath("win32", zigwin32_index_file);

        virtual_midi_sdk.addSdkPath(midilogger);

        midilogger.addPackage(.{
            .name = "audio",
            .path = .{ .path = "audio.zig" },
            .dependencies = &[_]std.build.Pkg{
                std.build.Pkg{ .name = "win32", .path = .{ .path = zigwin32_index_file } },
            }
        });

        b.step("midilogger", "Build/Install the midilogger tool").dependOn(&b.addInstallArtifact(midilogger).step);
    }
}

const virtual_midi_sdk = struct {
    pub const sdk_path = "C:\\Program Files (x86)\\Tobias Erichsen\\teVirtualMIDISDK";
    pub const c_binding_path = sdk_path ++ "\\C-Binding";
    pub fn addSdkPath(lib_exe_obj: *std.build.LibExeObjStep) void {
        const b = lib_exe_obj.builder;
        const check_step = b.allocator.create(std.build.Step) catch unreachable;
        check_step.* = std.build.Step.init(.custom, "check virtualMIDI SDK", b.allocator, checkVirtualMidiSdk);

        lib_exe_obj.step.dependOn(check_step);
        lib_exe_obj.addLibPath(c_binding_path);
    }
    fn checkVirtualMidiSdk(step: *std.build.Step) !void {
        _ = step;
        std.fs.accessAbsoluteZ(sdk_path, .{}) catch |err| {
            std.log.err("failed to access '{s}': {s}", .{sdk_path, @errorName(err)});
            std.log.err("Have you installed the virtualMIDI sdk from  http://www.tobias-erichsen.de/wp-content/uploads/2020/01/teVirtualMIDISDKSetup_1_3_0_43.zip", .{});
            std.os.exit(0xff);
        };
        std.fs.accessAbsoluteZ(c_binding_path, .{}) catch |err| {
            std.log.err("failed to access '{s}': {s}", .{c_binding_path, @errorName(err)});
            std.log.err("It appears you installed the virtualMIDI sdk without the C-Bindings?", .{});
            std.os.exit(0xff);
        };
    }
};
