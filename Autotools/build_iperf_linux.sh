#!/usr/bin/env bash

set -euo pipefail
set -x

# ---------------------- User-editable variables ----------------------
TOOLCHAIN=/opt/toolchain/gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu
# TOOLCHAIN=/opt/toolchain/gcc-linaro-7.4.1-2019.02-x86_64_aarch64-linux-gnu
# TOOLCHAIN=/opt/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf
# SYSROOT="${TOOLCHAIN}/aarch64-linux-gnu/libc"
ARCH=aarch64                           # aarch64, armv7a, etc.
PREFIX=/opt/linux-arm64                # Install prefix
BUILD_DIR=$(pwd)/build                 # Build directory
SRC_DIR=$(pwd)/src                     # Source directory
JOBS=$(nproc 2>/dev/null || echo 4)    # Number of parallel make jobs, default to 4 if nproc not available

IPERF_VER="3.19.1"                     # iperf version

IPERF_URL="https://github.com/esnet/iperf/releases/download/${IPERF_VER}/iperf-${IPERF_VER}.tar.gz"

DOWNLOAD_RETRIES=3                     # Number of download retries

# ---------------------- Target triple / openssl target ---------------
# target triple: <Architecture>-<System>-<Application Binary Interface>

case "$ARCH" in
  arm64|aarch64)
    TARGET_TRIPLE="aarch64-none-linux-gnu"    # aarch64-linux-gnu
    OPENSSL_TARGET="linux-aarch64"
    ;;
  armv7a|armhf|arm)
    TARGET_TRIPLE="arm-none-linux-gnueabihf"
    OPENSSL_TARGET="linux-armv4"
    ;;
  x86_64)
    TARGET_TRIPLE="x86_64-linux-gnu"
    OPENSSL_TARGET="linux-x86_64"
    ;;
  i386|x86)
    TARGET_TRIPLE="i686-linux-gnu"
    OPENSSL_TARGET="linux-elf"
    ;;
  *)
    echo "Unsupported ARCH: $ARCH"
    exit 1
    ;;
esac

# ---------------------- Toolchain variables ----------------------
CC="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-gcc"
CXX="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-g++"
AR="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-ar"
AS="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-as"
LD="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-ld"
RANLIB="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-ranlib"
STRIP="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-strip"
NM="${TOOLCHAIN}/bin/${TARGET_TRIPLE}-nm"

# ---------------------- Environment variables ----------------------
export PATH="${TOOLCHAIN}/bin:${PATH}"
export CC CXX AR AS LD RANLIB SYSROOTA
export CFLAGS="-fPIC -O2 -pipe"
export CXXFLAGS="-fPIC -O2 -pipe"
export LDFLAGS="-L${PREFIX}/lib"
export CPPFLAGS="-I${PREFIX}/include"
# Ensure pkgconfig looks at our prefix (important for configure scripts)
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"

echo "ARCH: $ARCH  TRIPLE: $TARGET_TRIPLE"
echo "CC: $CC" "CXX: $CXX" "AR: $AR" "AS: $AS" "LD: $LD" "RANLIB: $RANLIB" "STRIP: $STRIP" "NM: $NM"

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

build_iperf() {
  echo "=== Building iperf ==="
  if [ ! -d "${BUILD_DIR}/iperf-${IPERF_VER}" ]; then
    extract "${SRC_DIR}/iperf-${IPERF_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/iperf-${IPERF_VER}"

  # sudo apt install -y autoconf automake libtool pkg-config m4 autopoint autoconf-archive
  make clean || true
  ./configure \
    --build="$(uname -m)-linux-gnu" \
    --host="${TARGET_TRIPLE}" \
    --prefix="${PREFIX}" \
    --with-sysroot="${TOOLCHAIN}/${TARGET_TRIPLE}/libc" \
    --enable-static-bin \
    --enable-static \
    --enable-shared 

  make -j"${JOBS}"
  make install
  popd
}

# ---------------------- Main function -------------------------
main() {
    if [ ! -d "$TOOLCHAIN" ]; then
      echo "ERROR: TOOLCHAIN not found at $TOOLCHAIN. Please set TOOLCHAIN environment or edit the script."
      exit 1
    fi
    mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${PREFIX}"

    download "$IPERF_URL" "$SRC_DIR"

    build_iperf

    # strip executable(s) to save size
    if [ -f "${PREFIX}/lib/libiperf.a" ]; then
      $STRIP --strip-unneeded "${PREFIX}/lib/libiperf.a" || true
    fi

    echo "Build finished. Files installed to: ${PREFIX}"
    echo "Copy ${PREFIX} to device, set proper permissions and run ${PREFIX}/bin/iperf3 --version"
}

main "$@"
