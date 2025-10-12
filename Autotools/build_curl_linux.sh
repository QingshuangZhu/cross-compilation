#!/usr/bin/env bash

# set -euo pipefail
# set -x

# ---------------------- User-editable variables ----------------------
TOOLCHAIN=/opt/toolchain/gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu
# SYSROOT="${TOOLCHAIN}/aarch64-linux-gnu/libc"
ARCH=aarch64                           # aarch64, armv7a, etc.
PREFIX=/opt/linux-arm64                # Install prefix
BUILD_DIR=$(pwd)/build                 # Build directory
SRC_DIR=$(pwd)/src                     # Source directory
JOBS=$(nproc 2>/dev/null || echo 4)    # Number of parallel make jobs, default to 4 if nproc not available

ZLIB_VER="zlib-1.3.1"                  # zlib version
OPENSSL_VER="openssl-3.5.2"            # OpenSSL version
TONGSUO_VER="8.4.0"                    # tongsuo version
CURL_VER="curl-8.16.0"                 # cURL version

DOWNLOAD_RETRIES=3                     # Number of download retries

ZLIB_URL="https://zlib.net/${ZLIB_VER}.tar.xz"
OPENSSL_URL="https://www.openssl.org/source/${OPENSSL_VER}.tar.gz"
TONGSUO_URL="https://github.com/Tongsuo-Project/Tongsuo/archive/refs/tags/${TONGSUO_VER}.tar.gz"
CURL_URL="https://curl.se/download/${CURL_VER}.tar.xz"

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

build_zlib() {
  echo "=== Building zlib ==="
  if [ ! -d "${BUILD_DIR}/${ZLIB_VER}" ]; then
    extract "${SRC_DIR}/${ZLIB_VER}.tar.xz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/${ZLIB_VER}"
  if [ ! -f "${PREFIX}/include/zlib.h" ]; then
    make clean || true
    CHOST="${TARGET_TRIPLE}" ./configure --prefix="${PREFIX}" --static
    make -j"${JOBS}"
    make install
  else
    echo "zlib already installed in ${PREFIX}"
  fi
  popd
}

build_openssl() {
  echo "=== Building OpenSSL ==="
  if [ ! -d "${BUILD_DIR}/${OPENSSL_VER}" ]; then
    extract "${SRC_DIR}/${OPENSSL_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/${OPENSSL_VER}"
  if [ ! -f "${PREFIX}/include/openssl/ssl.h" ] || [ ! -f "${PREFIX}/lib/libcrypto.a" ] || [ ! -f "${PREFIX}/lib/libssl.a" ]; then
    make clean || true
    ./Configure "${OPENSSL_TARGET}" --prefix="${PREFIX}" no-shared no-unit-test
    make -j"${JOBS}"
    make install_sw
  else
    echo "OpenSSL already installed in ${PREFIX}"
  fi
  popd
}

build_tongsuo() {
  echo "=== Building Tongsuo ==="
  if [ ! -d "${BUILD_DIR}/${TONGSUO_VER}" ]; then
    extract "${SRC_DIR}/${TONGSUO_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/Tongsuo-${TONGSUO_VER}"
  if [ ! -f "${PREFIX}/include/openssl/ssl.h" ] || [ ! -f "${PREFIX}/lib/libcrypto.a" ] || [ ! -f "${PREFIX}/lib/libssl.a" ]; then
    make clean || true
    ./config "${OPENSSL_TARGET}" enable-ntls --prefix="${PREFIX}" no-shared no-unit-test
    make -j"${JOBS}"
    make install
  else
    echo "OpenSSL already installed in ${PREFIX}"
  fi
  popd
}

build_curl() {
  echo "=== Building cURL ==="
  if [ ! -d "${BUILD_DIR}/${CURL_VER}" ]; then
    extract "${SRC_DIR}/${CURL_VER}.tar.xz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/${CURL_VER}"

  # sudo apt install -y autoconf automake libtool pkg-config m4 autopoint autoconf-archive
  if [ ! -x "./configure" ] && [ -f "./autogen.sh" ]; then
    echo "Running autogen.sh to generate configure (requires autoconf/automake)"
    ./autogen.sh
  fi
  make clean || true
  ./configure \
    --host="${TARGET_TRIPLE}" \
    --prefix="${PREFIX}" \
    --with-zlib="${PREFIX}" \
    --with-openssl="${PREFIX}" \
    --without-bzip2 \
    --without-libpsl \
    --enable-ftp \
    --enable-static

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

    download "$ZLIB_URL" "$SRC_DIR"
    download "$OPENSSL_URL" "$SRC_DIR"
    # download "$TONGSUO_URL" "$SRC_DIR"
    download "$CURL_URL" "$SRC_DIR"
    
    build_zlib
    # build_openssl
    build_tongsuo
    build_curl
    # strip executable(s) to save size
    if [ -f "${PREFIX}/lib/libcurl.a" ]; then
      $STRIP --strip-unneeded "${PREFIX}/lib/libcurl.a" || true
    fi

    echo "Build finished. Files installed to: ${PREFIX}"
    echo "Copy ${PREFIX} to device, set proper permissions and run ${PREFIX}/bin/curl -V"
}

main "$@"
