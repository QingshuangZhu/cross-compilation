# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains cross-compilation build scripts for C/C++ projects across multiple platforms (Linux, Android, OpenHarmony) and architectures (x86_64, aarch64, aarch64_be, armv7a). Two build system approaches are covered: **Autotools** (autoconf/automake) and **CMake**.

Each script downloads source tarballs, builds dependencies (zlib, openssl, pcre, fcgi, etc.), then builds the target project, and installs everything to a platform/arch-specific prefix directory ready to be copied to a target device.

## Architecture

```
├── Autotools/
│   ├── build_<project>_<platform>.sh   # Entrypoint scripts (12 scripts: lighttpd, curl, nginx, iperf, microsocks × linux/android/ohos)
│   ├── src/                             # Source tarballs (downloaded or pre-staged)
│   ├── build/                           # Extracted source trees
│   ├── linux-x86_64/                    # Install output for linux-x86_64
│   ├── android-arm/                     # Install output for android-arm
│   └── ohos-arm64/                      # Install output for ohos-arm64
├── CMake/
│   ├── build_<project>_<platform>.sh    # Entrypoint scripts (protobuf, mosquitto, paho.mqtt.c, paho.mqtt.embedded-c, jsoncpp)
│   ├── arm-toolchain.cmake              # CMake toolchain for arm
│   ├── aarch64-toolchain.cmake          # CMake toolchain for aarch64
│   └── aarch64_be-toolchain.cmake       # CMake toolchain for aarch64_be
└── README.md                            # Project overview and toolchain setup instructions
```

## Key Patterns

### Shared Helper Functions

All build scripts share nearly identical implementations of:
- `download(url, outdir)` — downloads with retry (supports wget and curl), skips if file already exists
- `extract(tarball, destdir)` — auto-detects archive format (.tar.gz, .tar.xz, .zip)

When adding a new script, reuse these functions as-is.

### Autotools Scripts

Each script (e.g., `build_lighttpd_linux.sh`, `build_curl_linux.sh`) follows this structure:

1. **User-editable variables** at top: `TOOLCHAIN` (or `NDK` for Android/ohos), `ARCH`, `PREFIX`, `BUILD_DIR`, `SRC_DIR`, version strings, download URLs
2. **Target triple mapping**: `case "$ARCH"` block maps architecture names to compiler target triples and OpenSSL/Tongsuo build targets
3. **Toolchain variables**: Derives `CC`, `CXX`, `AR`, `RANLIB`, `STRIP` from target triple
4. **Environment exports**: `CFLAGS`, `LDFLAGS`, `CPPFLAGS`, `PKG_CONFIG_LIBDIR` all point to `${PREFIX}`
5. **Dependency build functions**: `build_zlib()`, `build_openssl()`, `build_pcre()`, `build_fcgi()` — each checks for installed artifacts before rebuilding
6. **Target build function**: `build_<project>()` — runs `./configure --host=<triple> --prefix=${PREFIX} ...` then `make && make install`
7. **main()**: Downloads sources, calls build functions in dependency order, strips binaries

**To add a new Autotools project**: Copy the most similar existing script, update version/URL variables, add a `build_<project>()` function, and call it from `main()` after its dependencies.

### CMake Scripts

CMake builds (e.g., `CMake/build_protobuf_linux.sh`) follow a similar structure but differ in:
1. **Toolchain file**: References a `.cmake` file via `CMAKE_TOOLCHAIN_FILE` instead of setting `CC`/`CXX` env vars
2. **Out-of-tree builds**: Creates a `build/` subdirectory inside the extracted source tree and runs `cmake ..` from there
3. **Multi-dependency projects**: Some scripts (e.g., `build_jsoncpp_linux.sh`) build chained dependencies (zip → jsoncpp) sequentially

**CMake toolchain files** (`CMake/*-toolchain.cmake`): Define `CMAKE_SYSTEM_NAME`, `CMAKE_SYSTEM_PROCESSOR`, compiler paths, `CMAKE_SYSROOT`, `CMAKE_FIND_ROOT_PATH`, and find-mode settings (`ONLY` for libs/includes, `NEVER` for programs).

### Platform Differences

| Platform | Variable | Compiler | Special Notes |
|----------|----------|----------|---------------|
| **linux** | `TOOLCHAIN=/usr` or `/opt/toolchain/...` | gcc/g++ | Standard cross-compilation |
| **android** | `NDK=/opt/android-ndk-r26d` | clang/clang++ | Uses NDK sysroot, `--with-sysroot` for configure |
| **ohos** | `NDK=/opt/toolchain/.../openharmony/native` | clang/clang++ | Needs `config.sub`/`config.guess` updates, OpenSSL `-D__MUSL__` flag |

## Common Operations

### Running a build
```bash
cd Autotools && ./build_<project>_<platform>.sh
cd CMake && ./build_<project>_<platform>.sh
```

### Adding a new project
1. Choose Autotools or CMake depending on the project's build system
2. Copy the most similar existing build script
3. Update version, URL, and build function
4. Ensure dependency ordering is correct (libraries before dependents)

### Adding a new architecture
1. For Autotools: add a case branch in the `case "$ARCH"` block with target triple and compiler paths
2. For CMake: create a new `*-toolchain.cmake` file following the existing pattern

## Important Details

- Source tarballs in `Autotools/src/` are reused across builds — `download()` skips if the file already exists
- Build functions check for installed artifacts (e.g., `${PREFIX}/include/zlib.h`) to skip already-built dependencies
- Parallel jobs use `$(nproc)` with a fallback of 4
- Download retries default to 3
- The `build/` directory holds extracted sources — safe to delete to force rebuilds
- Install output directories (`linux-x86_64/`, `android-arm/`, `ohos-arm64/`) contain `bin/`, `include/`, `lib/`, `lib64/`, `sbin/` — ready to copy to target devices
- The `build/` directory also contains extracted source trees from third-party projects (e.g., openssl-3.5.2/) — these are build artifacts, not project code
