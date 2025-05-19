const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const is_release = switch (optimize) {
        .ReleaseFast, .ReleaseSafe, .ReleaseSmall => true,
        else => false,
    };

    const exe_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = false,
        .strip = is_release,
    });

    const exe = b.addExecutable(.{
        .name = "no_crt",
        .root_module = exe_mod,
    });

    // Manually link library for MessageBoxA
    exe.linkSystemLibrary("user32");

    var flags = std.ArrayList([]const u8).init(b.allocator);
    if (std.fs.path.dirname(b.graph.zig_exe)) |zig_dir| {
        const paths = [_][]const u8{
            zig_dir,
            "lib",
            "libc",
            "include",
            "any-windows-any",
        };

        const lib_dir = std.fs.path.join(b.allocator, &paths) catch @panic("Out of memory");
        defer b.allocator.free(lib_dir);

        // Adding system include path for Windows header files
        // (Allows for #include <windows.h> and other includes)
        flags.append(b.fmt("-I{s}", .{lib_dir})) catch @panic("Append failed");
    } else {
        @panic("zig.exe has no directory");
    }

    exe.addCSourceFile(.{ .file = b.path("src/main.c"), .flags = flags.toOwnedSlice() catch @panic("No owned slice") });
    exe.entry = .{ .symbol_name = "test" };

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Note: By default argument passing without CRT
    // will not work, but it can work if the right
    // functions are called (__p___argv() and __p___argc()
    // in ucrtbase.dll), or if the behaviour of the
    // functions are emulated.

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
