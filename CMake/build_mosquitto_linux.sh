#!/usr/bin/env bash

# set -euo pipefail
# set -x

# ---------------------- User-editable variables ----------------------
TOOLCHAIN_FILE=$(pwd)/aarch64-toolchain.cmake
PREFIX=/opt/linux-arm64                # Install prefix
BUILD_DIR=$(pwd)/build                 # Build directory
SRC_DIR=$(pwd)/src                     # Source directory
JOBS=$(nproc 2>/dev/null || echo 4)    # Number of parallel make jobs, default to 4 if nproc not available

MOSQUITTO_VER="2.0.22"                 # Mosquitto version
MOSQUITTO_URL="https://mosquitto.org/files/source/mosquitto-${MOSQUITTO_VER}.tar.gz"

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

build_mosquitto() {
  local TOOLCHAIN_FILE="$1"
  echo "=== Building mosquitto ==="
  if [ ! -d "${BUILD_DIR}/mosquitto-${MOSQUITTO_VER}" ]; then
    extract "${SRC_DIR}/mosquitto-${MOSQUITTO_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/mosquitto-${MOSQUITTO_VER}"
  if [ ! -f "${PREFIX}/include/mosquitto.h" ]; then
    rm -rf build || true
    mkdir build && pushd build

    cmake \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_EXE_LINKER_FLAGS="-lpthread -ldl -latomic" \
        `# If it is ARM, uncomment the following line and comment out the above line.` \
        `# -DCMAKE_EXE_LINKER_FLAGS="-lpthread -ldl"` \
        -DWITH_TLS=ON \
        -DWITH_TLS_PSK=ON \
        -DWITH_EC=ON \
        -DWITH_STATIC_LIBRARIES=ON \
        -DWITH_PLUGINS=OFF \
        -DDOCUMENTATION=OFF \
        -DOPENSSL_ROOT_DIR="${PREFIX}" \
        -DOPENSSL_INCLUDE_DIR="${PREFIX}/include" \
        -DOPENSSL_SSL_LIBRARY="${PREFIX}/lib/libssl.a" \
        -DOPENSSL_CRYPTO_LIBRARY="${PREFIX}/lib/libcrypto.a" \
        ..
    make -j"${JOBS}"
    make install
    popd
  else
    echo "mosquitto already installed in ${PREFIX}"
  fi
  popd
}

# ---------------------- Main function -------------------------
main() {
    mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${PREFIX}"

    download "$MOSQUITTO_URL" "$SRC_DIR"

    build_mosquitto "$TOOLCHAIN_FILE"

    echo "Build finished. Files installed to: ${PREFIX}"
    echo "Copy ${PREFIX} to device, set proper permissions and run ${PREFIX}/bin/mosquitto_pub --version"
}

main "$@"
