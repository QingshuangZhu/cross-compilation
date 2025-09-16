#!/usr/bin/env bash

# set -euo pipefail
# set -x

# ---------------------- User-editable variables ----------------------
NDK=/opt/android-ndk-r26d              # Android NDK path
ARCH=aarch64                           # aarch64, armv7a, etc.
API=29                                 # Android API level
PREFIX=$(pwd)/android-root             # Install prefix
BUILD_DIR=$(pwd)/build                 # Build directory
SRC_DIR=$(pwd)/src                     # Source directory
JOBS=$(nproc 2>/dev/null || echo 4)    # Number of parallel make jobs, default to 4 if nproc not available

FCGI_VER="2.4.6"                       # FastCGI version
ZLIB_VER="zlib-1.3.1"                  # zlib version
PCRE_VER="8.45"                        # PCRE version
OPENSSL_VER="openssl-3.5.2"            # OpenSSL version
LIGHTTPD_VER="lighttpd-1.4.81"         # Lighttpd version

DOWNLOAD_RETRIES=3                     # Number of download retries

FCGI_URL="https://github.com/FastCGI-Archives/fcgi2/archive/refs/tags/${FCGI_VER}.tar.gz"

ZLIB_URL="https://zlib.net/${ZLIB_VER}.tar.xz"
PCRE_URL="https://downloads.sourceforge.net/project/pcre/pcre/${PCRE_VER}/pcre-${PCRE_VER}.tar.gz"
OPENSSL_URL="https://www.openssl.org/source/${OPENSSL_VER}.tar.gz"
LIGHTTPD_URL="https://download.lighttpd.net/lighttpd/releases-1.4.x/${LIGHTTPD_VER}.tar.xz"

# ---------------------- Target triple / openssl target ---------------
# target triple: <Architecture>-<System>-<Application Binary Interface>

case "$ARCH" in
  arm64|aarch64)
    TARGET_TRIPLE="aarch64-linux-android"
    OPENSSL_TARGET="android-arm64"
    ;;
  armv7a|armhf|arm)
    TARGET_TRIPLE="armv7a-linux-androideabi"
    OPENSSL_TARGET="android-arm"
    ;;
  x86_64)
    TARGET_TRIPLE="x86_64-linux-android"
    OPENSSL_TARGET="android-x86_64"
    ;;
  x86)
    TARGET_TRIPLE="i686-linux-android"
    OPENSSL_TARGET="android-x86"
    ;;
  *)
    echo "Unsupported ARCH: $ARCH"
    exit 1
    ;;
esac

# ---------------------- Toolchain variables ----------------------
TOOLCHAIN="${NDK}/toolchains/llvm/prebuilt/linux-x86_64"
SYSROOT="${TOOLCHAIN}/sysroot"
CC="${TOOLCHAIN}/bin/${TARGET_TRIPLE}${API}-clang"
CXX="${TOOLCHAIN}/bin/${TARGET_TRIPLE}${API}-clang++"
AR="${TOOLCHAIN}/bin/llvm-ar"
AS="${TOOLCHAIN}/bin/llvm-as"
RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
STRIP="${TOOLCHAIN}/bin/llvm-strip"
NM="${TOOLCHAIN}/bin/llvm-nm"

# ---------------------- Environment variables ----------------------
export ANDROID_NDK_HOME="$NDK"
export PATH="${TOOLCHAIN}/bin:${PATH}"
export CC CXX AR RANLIB SYSROOT
export CFLAGS="-fPIC -O2 -pipe"
export CXXFLAGS="-fPIC -O2 -pipe"
export LDFLAGS="-L${PREFIX}/lib"
export CPPFLAGS="-I${PREFIX}/include"
# Ensure pkgconfig looks at our prefix (important for configure scripts)
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"

echo "ANDROID_NDK_HOME: $ANDROID_NDK_HOME"
echo "ARCH: $ARCH  TRIPLE: $TARGET_TRIPLE  API: $API"
echo "CC: $CC" "CXX: $CXX" "AR: $AR" "RANLIB: $RANLIB" "STRIP: $STRIP" "NM: $NM"

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

build_fcgi() {
  echo "=== Building fcgi ==="
  if [ ! -d "${BUILD_DIR}/fcgi2-${FCGI_VER}" ]; then
    extract "${SRC_DIR}/fcgi2-${FCGI_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/fcgi2-${FCGI_VER}"
  if [ ! -f "${PREFIX}/include/fastcgi.h" ]; then
    make clean || true
    if [ ! -x "./configure" ] && [ -f "./autogen.sh" ]; then
      echo "Running autogen.sh to generate configure (requires autoconf/automake)"
      ./autogen.sh
    fi
    ./configure --host="${TARGET_TRIPLE}" --prefix="${PREFIX}" --with-pic
    make -j"${JOBS}"
    make install
  else
    echo "fcgi already installed in ${PREFIX}"
  fi
  popd
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

build_pcre() {
  echo "=== Building pcre ==="
  if [ ! -d "${BUILD_DIR}/pcre-${PCRE_VER}" ]; then
    extract "${SRC_DIR}/pcre-${PCRE_VER}.tar.gz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/pcre-${PCRE_VER}"
  if [ ! -f "${PREFIX}/include/pcre.h" ]; then
     make clean || true
    ./configure \
      --host="${TARGET_TRIPLE}" \
      --prefix="${PREFIX}" \
      --with-pic \
      --enable-utf \
      --enable-unicode-properties \
      --disable-shared \
      --disable-cpp \
      --disable-pcregrep-libz \
      --disable-pcregrep-libbz2 \
      --disable-tests \
      CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS"
    make -j"${JOBS}"
    make install
  else
    echo "pcre already installed in ${PREFIX}"
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
    ./Configure "${OPENSSL_TARGET}" no-shared no-unit-test --prefix="${PREFIX}" -D__ANDROID_API__="${API}"
    make -j"${JOBS}"
    make install_sw
  else
    echo "OpenSSL already installed in ${PREFIX}"
  fi
  popd
}

build_lighttpd() {
  echo "=== Building lighttpd ==="
  if [ ! -d "${BUILD_DIR}/${LIGHTTPD_VER}" ]; then
    extract "${SRC_DIR}/${LIGHTTPD_VER}.tar.xz" "${BUILD_DIR}"
  fi
  pushd "${BUILD_DIR}/${LIGHTTPD_VER}"

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
    --with-pcre="${PREFIX}" \
    --with-openssl="${PREFIX}" \
    --without-bzip2 \
    --enable-static \
    --disable-webdav \
    CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" PKG_CONFIG_LIBDIR="$PKG_CONFIG_LIBDIR"

  make -j"${JOBS}"
  make install
  popd
}

# ---------------------- Main function -------------------------
main() {
    if [ ! -d "$NDK" ]; then
      echo "ERROR: NDK not found at $NDK. Please set NDK environment or edit the script."
      exit 1
    fi
    mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${PREFIX}"

    download "$FCGI_URL" "$SRC_DIR"

    download "$ZLIB_URL" "$SRC_DIR"
    download "$PCRE_URL" "$SRC_DIR"
    download "$OPENSSL_URL" "$SRC_DIR"
    download "$LIGHTTPD_URL" "$SRC_DIR"

    build_fcgi

    build_zlib
    build_pcre
    build_openssl
    build_lighttpd
    strip executable(s) to save size
    if [ -f "${PREFIX}/sbin/lighttpd" ]; then
      $STRIP --strip-unneeded "${PREFIX}/sbin/lighttpd" || true
    fi

    echo "Build finished. Files installed to: ${PREFIX}"
    echo "Copy ${PREFIX} to device, set proper permissions and run ${PREFIX}/sbin/lighttpd -f /path/to/lighttpd.conf"
}

main "$@"
