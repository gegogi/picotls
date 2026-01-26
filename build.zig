const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build options
    const with_fusion = b.option(bool, "fusion", "Build 'fusion' AES-GCM engine") orelse false;

    // Detect Windows target
    const is_windows = target.result.os.tag == .windows;

    // Include directories
    const include_dirs: []const []const u8 = &.{
        "deps/cifra/src/ext",
        "deps/cifra/src",
        "deps/micro-ecc",
        "deps/picotest",
        "include",
    };

    // Windows-specific include directory
    const windows_include_dir = "picotlsvs/picotls";

    // Platform-specific flags
    const linux_cflags: []const []const u8 = &.{
        "-std=c99",
        "-Wall",
        "-D_GNU_SOURCE",
        "-Wno-shift-count-overflow",
    };

    const windows_cflags: []const []const u8 = &.{
        "-std=c99",
        "-Wall",
        "-D_WINDOWS",
        "-Wno-shift-count-overflow",
    };

    const common_cflags = if (is_windows) windows_cflags else linux_cflags;

    // Minicrypto library files (from cifra and micro-ecc)
    const minicrypto_library_files: []const []const u8 = &.{
        "deps/micro-ecc/uECC.c",
        "deps/cifra/src/aes.c",
        "deps/cifra/src/blockwise.c",
        "deps/cifra/src/chacha20.c",
        "deps/cifra/src/chash.c",
        "deps/cifra/src/curve25519.c",
        "deps/cifra/src/drbg.c",
        "deps/cifra/src/hmac.c",
        "deps/cifra/src/gcm.c",
        "deps/cifra/src/gf128.c",
        "deps/cifra/src/modes.c",
        "deps/cifra/src/poly1305.c",
        "deps/cifra/src/sha256.c",
        "deps/cifra/src/sha512.c",
    };

    // Core source files
    const core_files_base: []const []const u8 = &.{
        "lib/hpke.c",
        "lib/picotls.c",
        "lib/pembase64.c",
    };

    const core_files_windows: []const []const u8 = &.{
        "lib/hpke.c",
        "lib/picotls.c",
        "lib/pembase64.c",
        "picotlsvs/picotls/wintimeofday.c",
    };

    const core_files = if (is_windows) core_files_windows else core_files_base;

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

    if (is_windows) {
        core_module.addIncludePath(b.path(windows_include_dir));
        core_module.linkSystemLibrary("ws2_32", .{});
    }

    core_module.addCSourceFiles(.{
        .files = core_files,
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

    if (is_windows) {
        minicrypto_module.addIncludePath(b.path(windows_include_dir));
        minicrypto_module.linkSystemLibrary("bcrypt", .{});
    }

    minicrypto_module.addCSourceFiles(.{
        .files = minicrypto_library_files,
        .flags = common_cflags,
    });

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
    const test_files_base: []const []const u8 = &.{
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
    };

    const test_files_windows: []const []const u8 = &.{
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
        "picotlsvs/picotls/wintimeofday.c",
    };

    const test_files = if (is_windows) test_files_windows else test_files_base;

    const test_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    for (include_dirs) |dir| {
        test_module.addIncludePath(b.path(dir));
    }

    if (is_windows) {
        test_module.addIncludePath(b.path(windows_include_dir));
        test_module.linkSystemLibrary("ws2_32", .{});
        test_module.linkSystemLibrary("bcrypt", .{});
    }

    test_module.addCSourceFiles(.{
        .files = minicrypto_library_files,
        .flags = common_cflags,
    });

    test_module.addCSourceFiles(.{
        .files = test_files,
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
    // picotls-fusion library (optional, Linux only)
    // =======================
    if (with_fusion and !is_windows) {
        const fusion_cflags: []const []const u8 = &.{
            "-std=c99",
            "-Wall",
            "-D_GNU_SOURCE",
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
    const bench_cflags_linux: []const []const u8 = &.{
        "-std=c99",
        "-Wall",
        "-D_GNU_SOURCE",
        "-Wno-shift-count-overflow",
        "-DPTLS_MEMORY_DEBUG=1",
    };

    const bench_cflags_windows: []const []const u8 = &.{
        "-std=c99",
        "-Wall",
        "-D_WINDOWS",
        "-Wno-shift-count-overflow",
        "-DPTLS_MEMORY_DEBUG=1",
    };

    const bench_cflags = if (is_windows) bench_cflags_windows else bench_cflags_linux;

    const bench_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    for (include_dirs) |dir| {
        bench_module.addIncludePath(b.path(dir));
    }

    if (is_windows) {
        bench_module.addIncludePath(b.path(windows_include_dir));
        bench_module.linkSystemLibrary("ws2_32", .{});
        bench_module.linkSystemLibrary("bcrypt", .{});
    }

    bench_module.addCSourceFiles(.{
        .files = &.{"t/ptlsbench.c"},
        .flags = bench_cflags,
    });

    const ptlsbench = b.addExecutable(.{
        .name = "ptlsbench",
        .root_module = bench_module,
    });

    ptlsbench.linkLibrary(picotls_minicrypto);
    ptlsbench.linkLibrary(picotls_core);
    b.installArtifact(ptlsbench);
}
