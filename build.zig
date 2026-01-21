const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const with_fusion = b.option(bool, "fusion", "Build 'fusion' AES-GCM engine") orelse false;

    // Include directories
    const include_dirs: []const []const u8 = &.{
        "deps/cifra/src/ext",
        "deps/cifra/src",
        "deps/micro-ecc",
        "deps/picotest",
        "include",
    };

    // Minicrypto library files (from cifra and micro-ecc)
    const minicrypto_library_files: []const std.Build.Module.CSourceFile = &.{
        .{ .file = b.path("deps/micro-ecc/uECC.c") },
        .{ .file = b.path("deps/cifra/src/aes.c") },
        .{ .file = b.path("deps/cifra/src/blockwise.c") },
        .{ .file = b.path("deps/cifra/src/chacha20.c") },
        .{ .file = b.path("deps/cifra/src/chash.c") },
        .{ .file = b.path("deps/cifra/src/curve25519.c") },
        .{ .file = b.path("deps/cifra/src/drbg.c") },
        .{ .file = b.path("deps/cifra/src/hmac.c") },
        .{ .file = b.path("deps/cifra/src/gcm.c") },
        .{ .file = b.path("deps/cifra/src/gf128.c") },
        .{ .file = b.path("deps/cifra/src/modes.c") },
        .{ .file = b.path("deps/cifra/src/poly1305.c") },
        .{ .file = b.path("deps/cifra/src/sha256.c") },
        .{ .file = b.path("deps/cifra/src/sha512.c") },
    };

    // Common C flags
    const common_cflags: []const []const u8 = &.{
        "-std=c99",
        "-Wall",
        "-D_GNU_SOURCE",
        "-Wno-shift-count-overflow", // Macro has shift that's optimized away but triggers warning
    };

    // ===================
    // picotls-core library
    // ===================
    const core_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    for (include_dirs) |dir| {
        core_module.addIncludePath(b.path(dir));
    }

    core_module.addCSourceFiles(.{
        .files = &.{
            "lib/hpke.c",
            "lib/picotls.c",
            "lib/pembase64.c",
        },
        .flags = common_cflags,
    });

    const picotls_core = b.addLibrary(.{
        .name = "picotls-core",
        .linkage = .static,
        .root_module = core_module,
    });

    b.installArtifact(picotls_core);

    // =========================
    // picotls-minicrypto library
    // =========================
    const minicrypto_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    for (include_dirs) |dir| {
        minicrypto_module.addIncludePath(b.path(dir));
    }

    // Add minicrypto library files individually
    for (minicrypto_library_files) |src| {
        minicrypto_module.addCSourceFile(src);
    }

    minicrypto_module.addCSourceFiles(.{
        .files = &.{
            "lib/cifra.c",
            "lib/cifra/x25519.c",
            "lib/cifra/chacha20.c",
            "lib/cifra/aes128.c",
            "lib/cifra/aes256.c",
            "lib/cifra/random.c",
            "lib/minicrypto-pem.c",
            "lib/uecc.c",
            "lib/asn1.c",
            "lib/ffx.c",
        },
        .flags = common_cflags,
    });

    const picotls_minicrypto = b.addLibrary(.{
        .name = "picotls-minicrypto",
        .linkage = .static,
        .root_module = minicrypto_module,
    });

    picotls_minicrypto.linkLibrary(picotls_core);
    b.installArtifact(picotls_minicrypto);

    // ==========================
    // test-minicrypto executable
    // ==========================
    const test_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    for (include_dirs) |dir| {
        test_module.addIncludePath(b.path(dir));
    }

    // Add minicrypto library files
    for (minicrypto_library_files) |src| {
        test_module.addCSourceFile(src);
    }

    test_module.addCSourceFiles(.{
        .files = &.{
            "deps/picotest/picotest.c",
            "t/hpke.c",
            "t/picotls.c",
            "t/quiclb.c",
            "t/minicrypto.c",
            "lib/asn1.c",
            "lib/pembase64.c",
            "lib/ffx.c",
            "lib/cifra/x25519.c",
            "lib/cifra/chacha20.c",
            "lib/cifra/aes128.c",
            "lib/cifra/aes256.c",
            "lib/cifra/random.c",
        },
        .flags = common_cflags,
    });

    const test_minicrypto = b.addExecutable(.{
        .name = "test-minicrypto",
        .root_module = test_module,
    });

    b.installArtifact(test_minicrypto);

    // Run test-minicrypto
    const run_test_minicrypto = b.addRunArtifact(test_minicrypto);
    const test_step = b.step("test", "Run minicrypto tests");
    test_step.dependOn(&run_test_minicrypto.step);

    // =======================
    // picotls-fusion library (optional)
    // =======================
    if (with_fusion) {
        const fusion_cflags: []const []const u8 = &.{
            "-std=c99",
            "-Wall",
            "-DPTLS_HAVE_FUSION=1",
            "-mavx2",
            "-maes",
            "-mpclmul",
            "-mvaes",
            "-mvpclmulqdq",
        };

        const fusion_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        for (include_dirs) |dir| {
            fusion_module.addIncludePath(b.path(dir));
        }

        fusion_module.addCSourceFiles(.{
            .files = &.{"lib/fusion.c"},
            .flags = fusion_cflags,
        });

        const picotls_fusion = b.addLibrary(.{
            .name = "picotls-fusion",
            .linkage = .static,
            .root_module = fusion_module,
        });

        picotls_fusion.linkLibrary(picotls_core);
        b.installArtifact(picotls_fusion);

        // test-fusion executable
        const test_fusion_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

        for (include_dirs) |dir| {
            test_fusion_module.addIncludePath(b.path(dir));
        }

        test_fusion_module.addCSourceFiles(.{
            .files = &.{
                "deps/picotest/picotest.c",
                "lib/picotls.c",
                "t/fusion.c",
                "t/quiclb.c",
            },
            .flags = fusion_cflags,
        });

        const test_fusion = b.addExecutable(.{
            .name = "test-fusion",
            .root_module = test_fusion_module,
        });

        test_fusion.linkLibrary(picotls_minicrypto);
        b.installArtifact(test_fusion);
    }

    // =======================
    // ptlsbench executable
    // =======================
    const bench_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    for (include_dirs) |dir| {
        bench_module.addIncludePath(b.path(dir));
    }

    bench_module.addCSourceFiles(.{
        .files = &.{"t/ptlsbench.c"},
        .flags = &.{
            "-std=c99",
            "-Wall",
            "-D_GNU_SOURCE",
            "-Wno-shift-count-overflow",
            "-DPTLS_MEMORY_DEBUG=1",
        },
    });

    const ptlsbench = b.addExecutable(.{
        .name = "ptlsbench",
        .root_module = bench_module,
    });

    ptlsbench.linkLibrary(picotls_minicrypto);
    ptlsbench.linkLibrary(picotls_core);
    b.installArtifact(ptlsbench);
}
