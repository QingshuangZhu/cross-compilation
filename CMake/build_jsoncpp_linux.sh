#!/usr/bin/env bash

# set -euo pipefail
# set -x

# ---------------------- User-editable variables ----------------------
TOOLCHAIN_FILE=$(pwd)/aarch64_be-toolchain.cmake
PREFIX=/opt/linux-arm64_be             # Install prefix
BUILD_DIR=$(pwd)/build                 # Build directory
SRC_DIR=$(pwd)/src                     # Source directory
JOBS=$(nproc 2>/dev/null || echo 4)    # Number of parallel make jobs, default to 4 if nproc not available

JSONCPP_VER="1.9.6"                    # jsoncpp version
JSONCPP_URL="https://github.com/open-source-parsers/jsoncpp/archive/refs/tags/${JSONCPP_VER}.tar.gz"

ZIP_VER="0.3.5"                        # zip version
ZIP_URL="https://github.com/kuba--/zip/archive/refs/tags/v${ZIP_VER}.tar.gz"

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

build_jsoncpp() {
  local TOOLCHAIN_FILE="$1"
  echo "=== Building jsoncpp ==="
  if [ ! -d "${BUILD_DIR}/jsoncpp-${JSONCPP_VER}" ]; then
    extract "${SRC_DIR}/${JSONCPP_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/jsoncpp-${JSONCPP_VER}"
  if [ ! -f "${PREFIX}/include/json/json.h" ]; then
    rm -rf build || true
    mkdir build && pushd build
    cmake \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="${PREFIX}" \
        -DJSONCPP_WITH_TESTS=OFF \
        -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF \
        ..
    make -j"${JOBS}"
    make install
    popd
  else
    echo "jsoncpp already installed in ${PREFIX}"
  fi
  popd
}

build_zip() {
  local TOOLCHAIN_FILE="$1"
  echo "=== Building zip ==="
  if [ ! -d "${BUILD_DIR}/zip-${ZIP_VER}" ]; then
    extract "${SRC_DIR}/v${ZIP_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/zip-${ZIP_VER}"
  if [ ! -f "${PREFIX}/include/zip/zip.h" ]; then
    rm -rf build || true
    mkdir build && pushd build
    cmake \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH="${PREFIX}" \
        ..
    make -j"${JOBS}"
    make install
    popd
  else
    echo "zip already installed in ${PREFIX}"
  fi
  popd
}

# ---------------------- Main function -------------------------
main() {
    mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${PREFIX}"

    download "$JSONCPP_URL" "$SRC_DIR"
    download "$ZIP_URL" "$SRC_DIR"

    build_jsoncpp "$TOOLCHAIN_FILE"
    build_zip "$TOOLCHAIN_FILE"

    echo "Build finished. Files installed to: ${PREFIX}"
    echo "Copy ${PREFIX} to device"
}

main "$@"