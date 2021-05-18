const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const zigwin32_index_file = try (GitRepo {
        .url = "https://github.com/marlersoft/zigwin32",
        .branch = "10.0.19041.202-preview",
        .sha = "ee36e22f16e08045ba0cbfefa1121122bb2b9566",
    }).resolveOneFile(b.allocator, "win32.zig");

    const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("audio", "main.zig");
    exe.setBuildMode(mode);
    exe.install();
    exe.addPackagePath("stdext", "stdext.zig");
    exe.addPackagePath("win32", zigwin32_index_file);

    const windows_midi = b.addExecutable("windows-midi", "tools" ++ std.fs.path.sep_str ++ "windows-midi.zig");
    windows_midi.setBuildMode(mode);
    windows_midi.install();
    windows_midi.addPackagePath("win32", zigwin32_index_file);

    const runCommand = exe.run();
    runCommand.step.dependOn(b.getInstallStep());

    const runStep = b.step("run", "Run the app");
    runStep.dependOn(&runCommand.step);
}

pub const GitRepo = struct {
    url: []const u8,
    branch: ?[]const u8,
    sha: []const u8,
    path: ?[]const u8 = null,

    pub fn defaultReposDir(allocator: *std.mem.Allocator) ![]const u8 {
        const cwd = try std.process.getCwdAlloc(allocator);
        defer allocator.free(cwd);
        return try std.fs.path.join(allocator, &[_][]const u8 { cwd, "dep" });
    }

    pub fn resolve(self: GitRepo, allocator: *std.mem.Allocator) ![]const u8 {
        var optional_repos_dir_to_clean: ?[]const u8 = null;
        defer {
            if (optional_repos_dir_to_clean) |p| {
                allocator.free(p);
            }
        }

        const path = if (self.path) |p| try allocator.dupe(u8, p) else blk: {
            const repos_dir = try defaultReposDir(allocator);
            optional_repos_dir_to_clean = repos_dir;
            break :blk try std.fs.path.join(allocator, &[_][]const u8{ repos_dir, std.fs.path.basename(self.url) });
        };
        errdefer allocator.free(path);

        std.fs.accessAbsolute(path, std.fs.File.OpenFlags { .read = true }) catch |err| {
            std.debug.print("Error: repository '{s}' does not exist\n", .{path});
            std.debug.print("       Run the following to clone it:\n", .{});
            const branch_args = if (self.branch) |b| &[2][]const u8 {" -b ", b} else &[2][]const u8 {"", ""};
            std.debug.print("       git clone {s}{s}{s} {s} && git -C {3s} checkout {s} -b for_wrc\n",
                .{self.url, branch_args[0], branch_args[1], path, self.sha});
            std.os.exit(1);
        };

        // TODO: check if the SHA matches an print a message and/or warning if it is different

        return path;
    }

    pub fn resolveOneFile(self: GitRepo, allocator: *std.mem.Allocator, index_sub_path: []const u8) ![]const u8 {
        const repo_path = try self.resolve(allocator);
        defer allocator.free(repo_path);
        return try std.fs.path.join(allocator, &[_][]const u8 { repo_path, index_sub_path });
    }
};
