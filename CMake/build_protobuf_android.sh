#!/usr/bin/env bash

# set -euo pipefail
# set -x

# ---------------------- User-editable variables ----------------------
NDK=/opt/android-ndk-r26d              # Android NDK path
ARCH=arm64-v8a                         # arm64-v8a, armeabi-v7a, etc.
API=29                                 # Android API level
PREFIX=$(pwd)/android-root             # Install prefix
BUILD_DIR=$(pwd)/build                 # Build directory
SRC_DIR=$(pwd)/src                     # Source directory
JOBS=$(nproc 2>/dev/null || echo 4)    # Number of parallel make jobs, default to 4 if nproc not available

PROTOBUF_VER="32.1"                    # Protobuf version
PROTOBUF_URL="https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VER}/protobuf-${PROTOBUF_VER}.tar.gz"

DOWNLOAD_RETRIES=3                     # Number of download retries

# ---------------------- Helper functions ----------------------
download() {
  local url="$1"; local outdir="$2"; local attempts=0
  mkdir -p "$outdir"
  local fname
  fname="$(basename "$url")"
  local dest="${outdir}/${fname}"
  if [ -f "$dest" ]; then
    echo "Found existing $dest"
    return 0
  fi
  while [ $attempts -lt $DOWNLOAD_RETRIES ]; do
    attempts=$((attempts+1))
    echo "Downloading ($attempts/$DOWNLOAD_RETRIES): $url"
    if command -v wget >/dev/null 2>&1; then
      wget --timeout=20 --tries=3 -O "$dest" "$url" && break
    else
      curl -fSL --retry 3 -o "$dest" "$url" && break
    fi
    echo "Download failed, retrying..."
    sleep 1
  done
  if [ ! -f "$dest" ]; then
    echo "Failed to download $url"
    return 1
  fi
}

extract() {
  local tarball="$1"; local destdir="$2"
  mkdir -p "$destdir"
  case "$tarball" in
    *.tar.gz|*.tgz) tar xzf "$tarball" -C "$destdir" ;;
    *.tar.xz) tar xJf "$tarball" -C "$destdir" ;;
    *.zip) unzip -q "$tarball" -d "$destdir" ;;
    *) echo "Unsupported archive: $tarball"; return 1 ;;
  esac
}

build_protobuf() {
  local TOOLCHAIN_FILE="$1"
  echo "=== Building protobuf ==="
  if [ ! -d "${BUILD_DIR}/protobuf-${PROTOBUF_VER}" ]; then
    extract "${SRC_DIR}/protobuf-${PROTOBUF_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/protobuf-${PROTOBUF_VER}"
  if [ ! -f "${PREFIX}/include/google/protobuf/descriptor.h" ]; then
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DANDROID_NDK="${NDK}" \
        -DANDROID_ABI="${ARCH}" \
        -DANDROID_NATIVE_API_LEVEL="${API}" \
        -DANDROID_TOOLCHAIN=clang \
        -DCMAKE_GENERATOR="Ninja" \
        -DCMAKE_MAKE_PROGRAM=ninja \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -Dprotobuf_INSTALL=ON \
        -Dprotobuf_BUILD_PROTOBUF_BINARIES=ON \
        -Dprotobuf_BUILD_LIBUPB=ON \
        -Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
        -Dprotobuf_BUILD_TESTS=OFF \
        .
    ninja install
  else
    echo "protobuf already installed in ${PREFIX}"
  fi
  popd
}

# ---------------------- Main function -------------------------
main() {
    mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${PREFIX}"

    download "$PROTOBUF_URL" "$SRC_DIR"

    build_protobuf "${NDK}/build/cmake/android.toolchain.cmake"

    echo "Build finished. Files installed to: ${PREFIX}"
    echo "Copy ${PREFIX} to device, set proper permissions and run ${PREFIX}/bin/protoc --version"
}

main "$@"