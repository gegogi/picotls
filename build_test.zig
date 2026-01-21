const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    
    module.addIncludePath(b.path("include"));
    module.addCSourceFile(.{
        .file = b.path("lib/picotls.c"),
        .flags = &.{"-std=c99"},
    });
    
    const lib = b.addLibrary(.{
        .name = "test",
        .linkage = .static,
        .root_module = module,
    });
    
    b.installArtifact(lib);
}
