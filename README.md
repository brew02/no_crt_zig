# CRT-less C Windows Executables with Zig Build System

![Zig: 0.14.0](https://img.shields.io/badge/Zig%20Version-0.14.0-brightgreen.svg)

Recently I found it necessary to remove the C Run-Time (CRT) from an executable that I was building with the Zig build system and compiler. Unfortunately, I couldn't much useful information online as to how this could be achieved, so I created this repository to demonstrate and explain how to do this for those that might be interested.

## Removing CRT

The first few lines of the `build.zig` file are pretty standard. The first two notable lines are the following:

```zig
.link_libc = false,
.strip = is_release,
```

As you might guess, the first line is saying that we do not want to link LibC, which actually removes almost all of the CRT right off the bat, but it also cripples the usability of the executable as external headers such as `windows.h` can no longer be used, the `main` entry-point is invalid, and arguments can no longer be passed<sup>[1](#notes)</sup>.

The second line is saying that if we are in release mode, we want to strip debug symbols. While this is not strictly necessary, it's an option that I find to be useful, so I added it in.

The next interesting line is the following:

```zig
exe.linkSystemLibrary("user32");
```

Fortunately for us, Zig makes it very easy to include system libraries as it comes shipped with most important libraries for Windows and other systems. This is part of the beauty of using the Zig build system. This design decision makes it trivial to manually tell the build system that our executable has a dependency on user32.dll (for MessageBoxA<sup>[2](#notes)</sup>).

Unfortunately, we are only about halfway from solving our problem. At this point it would be possible to do the following in `main.c`:

```c
extern int MessageBoxA(void*, const char*, const char*, unsigned int);

int wWinMainCRTStartup() {
    MessageBoxA(0, "Test", 0, 0);
    return 0;
}
```

While this will do what we want, it can become tedious to manually define each symbol that you want to use in your executable, especially without the ability to use the various typedefs provided by `windows.h` and other header files.

To be able to use these header files within our C files, we need to make it known that the path containing such header files should be searched. To do this, we write the following:

```zig
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

    flags.append(b.fmt("-I{s}", .{lib_dir})) catch @panic("Append failed");
} else {
    @panic("zig.exe has no directory");
}

exe.addCSourceFile(.{ .file = b.path("src/main.c"), .flags = flags.toOwnedSlice() catch @panic("No owned slice") });
```

There is a lot more going on in these lines than the previous exmaples, so lets break it down. We start by using the `std.fs.path.dirname` function on the path to `zig.exe` to get the directory that contains `zig.exe`, which should always exist, but since it's an optional value we need to use the special Zig syntax to deal with it.

This root directory that contains `zig.exe` also contains a sub-directory called `lib/`. This directory, in turn, contains other sub-directories, and we can build a chain of these sub-directories until we reach the one of interest: `any-windows-any/`.

We then join these strings together to form a full path using the `std.fs.path.join` function.

We can then use this path as a flag to tell the C compiler where it can search for the header files that we are including in `<>`. Since Zig currently uses Clang as a compiler backend for C and C++ code, we can do this by using the `-I` flag. We append this flag to our `ArrayList` of flags and use those flags (just one in this case) when we add our C source file as part of the compilation process.

The final line of interest is the following:

```zig
exe.entry = .{ .symbol_name = "test" };
```

As is quite evident, this line defines a custom entry-point called `test` for the executable.

At this point we have combined all of the necessary components to effectively remote CRT from our executable. If we compile the program using `zig build` we find that the resulting executable is only **3KB**, with most of the space taken up by the page padding between the various sections. If size is still a concern, it is more than possible to create a linker script that can be used by `build.zig` to merge these sections together.

## Notes

<sup>1</sup>This example does **not** show how to pass arguments to CRT-less executables as this is completely normal behaviour, but it is possible to get arguments using `__p___argv` and `__p___argc` from `ucrtbase.dll`.

<sup>2</sup>To find which library needs to be linked, it is recommended to find the function on [MSDN](https://learn.microsoft.com/en-us/windows/win32/api/) and use the "Requirements" section.

## More Zig Build Information

I recommend going through [this post](https://ziggit.dev/t/build-system-tricks/3531) for more tips on how to use the Zig build system.
