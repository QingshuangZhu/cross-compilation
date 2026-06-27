# Repository Guidelines

## Project Structure & Module Organization
This repository contains cross-compilation scripts for C/C++ dependencies and target projects. `Autotools/` holds `build_<project>_<platform>.sh` entrypoints for packages such as lighttpd, curl, nginx, iperf, and microsocks. `CMake/` holds similar scripts for protobuf, mosquitto, paho.mqtt, and jsoncpp, plus `*-toolchain.cmake` files. `README.md` documents toolchain setup, while `CLAUDE.md` records project patterns for agent-assisted work.

Generated content is common: `src/` stores downloaded tarballs, `build/` stores extracted sources, and platform directories such as `linux-x86_64/`, `android-arm/`, and `ohos-arm64/` store install outputs. Treat these as build artifacts unless a task explicitly requires updating them.

## Build, Test, and Development Commands
- `cd Autotools && ./build_lighttpd_linux.sh`: downloads dependencies, configures with Autotools, builds, and installs to the script's `PREFIX`.
- `cd Autotools && ./build_nginx_android.sh`: example Android/NDK Autotools build.
- `cd CMake && ./build_protobuf_linux.sh`: builds protobuf using `CMAKE_TOOLCHAIN_FILE`.
- `cd CMake && ./build_jsoncpp_linux.sh`: example CMake build with chained dependencies.

Before running a script, confirm its top-level `TOOLCHAIN`, `NDK`, `ARCH`, and `PREFIX` values match your machine. Scripts may download sources, so expect network access and large generated directories.

## Coding Style & Naming Conventions
Use Bash for build entrypoints with `#!/usr/bin/env bash` and `set -euo pipefail`. Keep the existing section layout: user-editable variables, helper functions, dependency build functions, target build function, then `main()`. Prefer uppercase global configuration names (`PREFIX`, `BUILD_DIR`, `DOWNLOAD_RETRIES`) and lowercase function names (`download`, `extract`, `build_zlib`). Name new scripts `build_<project>_<platform>.sh` and new CMake toolchains `<arch>-toolchain.cmake`.

## Testing Guidelines
There is no dedicated first-party test framework. Validate changes by running the narrowest affected build script and checking installed artifacts under `PREFIX` (`bin/`, `include/`, `lib/`, or `sbin/`). For CMake changes, verify the configured toolchain file is used. For Autotools changes, verify `--host`, compiler variables, and dependency detection point to the target prefix.

## Commit & Pull Request Guidelines
Recent history uses short imperative summaries such as `Fix Android NDK path` and `Add the aarch64_be toolchain`. Keep commits focused on one script, toolchain, or package family. Pull requests should describe the target platform/architecture, commands run, resulting install prefix, and any required local toolchain paths. Note skipped validation when a build cannot be run locally.

## Security & Configuration Tips
Do not commit local IDE settings, downloaded archives, extracted dependency trees, or install outputs unless intentionally updating vendored artifacts. Avoid hard-coding private paths beyond documented defaults like `/opt/toolchain` and `/opt/android-ndk-r26d`.
