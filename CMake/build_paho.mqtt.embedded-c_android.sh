#!/usr/bin/env bash

# set -euo pipefail
# set -x

# ---------------------- User-editable variables ----------------------
NDK=/opt/android-ndk-r26d              # Android NDK path
ARCH=arm64-v8a                         # arm64-v8a, armeabi-v7a, etc.
API=29                                 # Android API level
PREFIX=/opt/android-arm64              # Install prefix
BUILD_DIR=$(pwd)/build                 # Build directory
SRC_DIR=$(pwd)/src                     # Source directory
JOBS=$(nproc 2>/dev/null || echo 4)    # Number of parallel make jobs, default to 4 if nproc not available

MBEDTLS_VER="4.0.0"                    # Mbed TLS version
PAHO_MQTT_EMBEDDED_C_VER="1.1.0"       # paho.mqtt.embedded-c version

MBEDTLS_URL="https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-${MBEDTLS_VER}/mbedtls-${MBEDTLS_VER}.tar.bz2"
PAHO_MQTT_EMBEDDED_C_URL="https://github.com/eclipse-paho/paho.mqtt.embedded-c/archive/refs/tags/v${PAHO_MQTT_EMBEDDED_C_VER}.tar.gz"

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

build_mbedtls() {
  local TOOLCHAIN_FILE="$1"
  echo "=== Building mbedtls ==="
  if [ ! -d "${BUILD_DIR}/mbedtls-${MBEDTLS_VER}" ]; then
    extract "${SRC_DIR}/mbedtls-${MBEDTLS_VER}.tar.bz2" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/mbedtls-${MBEDTLS_VER}"
  if [ ! -f "${PREFIX}/include/mbedtls/ssl.h" ]; then
    rm -rf build || true
    mkdir build && pushd build
    cmake \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_GENERATOR="Ninja" \
        -DCMAKE_MAKE_PROGRAM=ninja \
        -DANDROID_TOOLCHAIN=clang \
        -DANDROID_NDK="${NDK}" \
        -DANDROID_ABI="${ARCH}" \
        -DANDROID_NATIVE_API_LEVEL="${API}" \
        ..
    ninja install
    popd
  else
    echo "mbedtls already installed in ${PREFIX}"
  fi
  popd
}

build_paho_mqtt_embedded_c() {
  local TOOLCHAIN_FILE="$1"
  echo "=== Building paho.mqtt.embedded-c ==="
  if [ ! -d "${BUILD_DIR}/paho.mqtt.embedded-c-${PAHO_MQTT_EMBEDDED_C_VER}" ]; then
    extract "${SRC_DIR}/v${PAHO_MQTT_EMBEDDED_C_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/paho.mqtt.embedded-c-${PAHO_MQTT_EMBEDDED_C_VER}"
  if [ ! -f "${PREFIX}/include/MQTTClient.h" ]; then
    rm -rf build || true
    mkdir build && pushd build
    cmake \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAIN_FILE}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_GENERATOR="Ninja" \
        -DCMAKE_MAKE_PROGRAM=ninja \
        -DANDROID_TOOLCHAIN=clang \
        -DANDROID_NDK="${NDK}" \
        -DANDROID_ABI="${ARCH}" \
        -DANDROID_NATIVE_API_LEVEL="${API}" \
        ..
    ninja install
    popd
  else
    echo "paho.mqtt.embedded-c already installed in ${PREFIX}"
  fi
  popd
}

# ---------------------- Main function -------------------------
main() {
    mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${PREFIX}"

    download "$MBEDTLS_URL" "$SRC_DIR"
    download "$PAHO_MQTT_EMBEDDED_C_URL" "$SRC_DIR"

    build_mbedtls "${NDK}/build/cmake/android.toolchain.cmake"
    build_paho_mqtt_embedded_c "${NDK}/build/cmake/android.toolchain.cmake"

    echo "Build finished. Files installed to: ${PREFIX}"
    echo "Copy ${PREFIX} to device"
}

main "$@"
