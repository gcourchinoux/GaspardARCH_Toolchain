#!/usr/bin/env bash
# Run with: bash GaspardARCH/build-toolchain.sh binutils|gcc|libgcc
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TARGET=gaspardarc-unknown-elf
PREFIX=${PREFIX:-"$ROOT/build-gaspardarc-install"}
JOBS=${JOBS:-4}
BUILD_TRIPLET=${BUILD_TRIPLET:-x86_64-w64-mingw32}
HOST_TRIPLET=${HOST_TRIPLET:-$BUILD_TRIPLET}
export PATH="$PREFIX/bin:$PATH"
LEGACY='-O1 -std=gnu89 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types'
export CC_FOR_BUILD=${CC_FOR_BUILD:-"gcc $LEGACY"}
export CFLAGS_FOR_TARGET="${CFLAGS_FOR_TARGET:--O2 -ffreestanding}"
case ${1:-binutils} in
binutils)
  mkdir -p "$ROOT/build-binutils-gaspardarc"
  cd "$ROOT/build-binutils-gaspardarc"
  CFLAGS="${CFLAGS:-$LEGACY}" "$ROOT/binutils-2.25/configure" \
    --build="$BUILD_TRIPLET" --host="$HOST_TRIPLET" --target="$TARGET" \
    --prefix="$PREFIX" --disable-nls --disable-werror --disable-shared \
    --disable-gold --disable-gprof
  make -j"$JOBS" MAKEINFO=true
  make MAKEINFO=true install
  ;;
gcc)
  command -v "$TARGET-as" >/dev/null
  mkdir -p "$ROOT/build-gcc-gaspardarc"
  cd "$ROOT/build-gcc-gaspardarc"
  CFLAGS="${CFLAGS:-$LEGACY}" CXXFLAGS="${CXXFLAGS:--O1}" \
  "$ROOT/gcc-4.6.4/configure" \
    --build="$BUILD_TRIPLET" --host="$HOST_TRIPLET" --target="$TARGET" \
    --prefix="$PREFIX" --enable-languages=c --without-headers --with-newlib \
    --with-gnu-as --with-gnu-ld --disable-bootstrap --disable-nls \
    --disable-werror --disable-multilib --disable-shared --disable-threads \
    --disable-lto --disable-libssp --disable-libgomp --disable-libquadmath \
    --disable-libmudflap --disable-decimal-float --without-ppl --without-cloog
  make -j"$JOBS" MAKEINFO=true "CC_FOR_BUILD=$CC_FOR_BUILD" all-gcc
  make MAKEINFO=true "CC_FOR_BUILD=$CC_FOR_BUILD" install-gcc
  ;;
libgcc)
  cd "$ROOT/build-gcc-gaspardarc"
  make -j"$JOBS" MAKEINFO=true "CC_FOR_BUILD=$CC_FOR_BUILD" all-target-libgcc
  make MAKEINFO=true "CC_FOR_BUILD=$CC_FOR_BUILD" install-target-libgcc
  ;;
*) echo 'Usage: bash GaspardARCH/build-toolchain.sh binutils|gcc|libgcc' >&2;exit 2 ;;
esac
