// tested with zig version 0.11.0
const std = @import("std");
const Builder = std.build.Builder;
const GitRepoStep = @import("GitRepoStep.zig");

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const stdext = b.createModule(.{
        .source_file = .{ .path = "stdext.zig" },
    });

    const zigwin32_repo = GitRepoStep.create(b, .{
        .url = "https://github.com/marlersoft/zigwin32",
        .branch = "21.0.3-preview",
        .sha = "e61d5e9cc18bc254d3e495e53ec02f9690793575",
    });
    const zigwin32 = b.createModule(.{
        .source_file = .{ .path = b.pathJoin(&.{zigwin32_repo.path, "win32.zig"}), },
    });
    
    {
        const exe = b.addExecutable(.{
            .name = "audio",
            .root_source_file = .{ .path = "main.zig" },
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(exe);
        exe.addModule("stdext", stdext);
        exe.step.dependOn(&zigwin32_repo.step);
        exe.addModule("win32", zigwin32);

        const run = b.addRunArtifact(exe);
        run.step.dependOn(b.getInstallStep());

        const runStep = b.step("run", "Run the app");
        runStep.dependOn(&run.step);
    }

//    {
//        const exe = b.addExecutable("midistatus", "tools" ++ std.fs.path.sep_str ++ "midistatus.zig");
//        exe.setTarget(target);
//        exe.setBuildMode(optimize);
//        exe.install();
//        exe.step.dependOn(&zigwin32_repo.step);
//        const zigwin32_index_file = b.pathJoin(&.{zigwin32_repo.getPath(&exe.step), "win32.zig"});
//        exe.addPackagePath("win32", zigwin32_index_file);
//        exe.addPackage(.{
//            .name = "audio",
//            .path = .{ .path = "audio.zig" },
//            .dependencies = &[_]std.build.Pkg{
//                std.build.Pkg{ .name = "win32", .path = .{ .path = zigwin32_index_file } },
//            }
//        });
//    }
//
//    {
//        const exe = b.addExecutable("midirecorder", "tools" ++ std.fs.path.sep_str ++ "midirecorder.zig");
//        exe.setTarget(target);
//        exe.setBuildMode(optimize);
//        exe.install();
//        exe.step.dependOn(&zigwin32_repo.step);
//        const zigwin32_index_file = b.pathJoin(&.{zigwin32_repo.getPath(&exe.step), "win32.zig"});
//        exe.addPackagePath("win32", zigwin32_index_file);
//
//        exe.addPackage(.{
//            .name = "audio",
//            .path = .{ .path = "audio.zig" },
//            .dependencies = &[_]std.build.Pkg{
//                std.build.Pkg{ .name = "win32", .path = .{ .path = zigwin32_index_file } },
//            }
//        });
//    }
//
//    {
//        const exe = b.addExecutable("midipatch", "tools" ++ std.fs.path.sep_str ++ "midipatch.zig");
//        exe.setTarget(target);
//        exe.setBuildMode(optimize);
//        exe.install();
//        exe.step.dependOn(&zigwin32_repo.step);
//        const zigwin32_index_file = b.pathJoin(&.{zigwin32_repo.getPath(&exe.step), "win32.zig"});
//        exe.addPackagePath("win32", zigwin32_index_file);
//
//        virtual_midi_sdk.addSdkPath(exe);
//
//        exe.addPackage(.{
//            .name = "audio",
//            .path = .{ .path = "audio.zig" },
//            .dependencies = &[_]std.build.Pkg{
//                std.build.Pkg{ .name = "win32", .path = .{ .path = zigwin32_index_file } },
//            }
//        });
//    }
//
//    const have_virtual_midi_sdk = virtual_midi_sdk.haveVirtualMidiSdk();
//
//    {
//        const exe = b.addExecutable("midilogger", "tools" ++ std.fs.path.sep_str ++ "midilogger.zig");
//        exe.setTarget(target);
//        exe.setBuildMode(optimize);
//        exe.step.dependOn(&zigwin32_repo.step);
//        const zigwin32_index_file = b.pathJoin(&.{zigwin32_repo.getPath(&exe.step), "win32.zig"});
//        exe.addPackagePath("win32", zigwin32_index_file);
//
//        virtual_midi_sdk.addSdkPath(exe);
//
//        exe.addPackage(.{
//            .name = "audio",
//            .path = .{ .path = "audio.zig" },
//            .dependencies = &[_]std.build.Pkg{
//                std.build.Pkg{ .name = "win32", .path = .{ .path = zigwin32_index_file } },
//            }
//        });
//
//        const install_step = b.addInstallArtifact(exe);
//        b.step("midilogger", "Build/Install the midilogger tool").dependOn(&install_step.step);
//        if (have_virtual_midi_sdk) {
//            b.default_step.dependOn(&install_step.step);
//        }
//    }
//
//    {
//        const exe = b.addExecutable("midimaestro", "tools" ++ std.fs.path.sep_str ++ "midimaestro.zig");
//        exe.setTarget(target);
//        exe.setBuildMode(optimize);
//        exe.step.dependOn(&zigwin32_repo.step);
//        const zigwin32_index_file = b.pathJoin(&.{zigwin32_repo.getPath(&exe.step), "win32.zig"});
//        exe.addPackagePath("win32", zigwin32_index_file);
//
//        virtual_midi_sdk.addSdkPath(exe);
//
//        exe.addPackage(.{
//            .name = "audio",
//            .path = .{ .path = "audio.zig" },
//            .dependencies = &[_]std.build.Pkg{
//                std.build.Pkg{ .name = "win32", .path = .{ .path = zigwin32_index_file } },
//            }
//        });
//
//        const install_step = b.addInstallArtifact(exe);
//        b.step("midimaestro", "Build/Install the midimaestro tool").dependOn(&install_step.step);
//        if (have_virtual_midi_sdk) {
//            b.default_step.dependOn(&install_step.step);
//        }
//    }
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
    pub fn haveVirtualMidiSdk() bool {
        std.fs.accessAbsoluteZ(c_binding_path, .{}) catch return false;
        return true;
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
