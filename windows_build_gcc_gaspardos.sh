#!/usr/bin/env bash
set -euo pipefail

# À lancer dans le même environnement MinGW64 que binutils.
# Exemple :
# JOBS=8 PREFIX=/c/projets/compilo-gaspardos/build bash script.sh

TARGET="${TARGET:-i386-gaspardos}"
PREFIX="${PREFIX:-/c/projets/compilo-gaspardos/build}"
SRC="${SRC:-/c/projets/compilo-gaspardos/gcc-4.6.4}"
BUILD="${BUILD:-$SRC/build-gcc}"
JOBS="${JOBS:-4}"
BUILD_TRIPLET="${BUILD_TRIPLET:-x86_64-w64-mingw32}"
HOST_TRIPLET="${HOST_TRIPLET:-x86_64-w64-mingw32}"

export PATH="$PREFIX/bin:$PATH"

# Compatibility with old GCC/GMP configure tests on modern host GCC.
# GMP invokes CC_FOR_BUILD directly, without CFLAGS_FOR_BUILD.
LEGACY_CFLAGS="-std=gnu89 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion"
export CC_FOR_BUILD="${CC_FOR_BUILD:-gcc $LEGACY_CFLAGS}"
export CFLAGS="${CFLAGS:--O1 $LEGACY_CFLAGS}"

# Vérifier que les binutils de la cible sont installés.
for tool in gcc make "${TARGET}-as" "${TARGET}-ld" "${TARGET}-ar"; do
    command -v "$tool" >/dev/null || {
        printf 'Outil introuvable : %s\n' "$tool" >&2
        exit 1
    }
done

test -f "$SRC/configure" || {
    printf 'Sources GCC introuvables : %s\n' "$SRC" >&2
    exit 1
}

mkdir -p "$BUILD"
cd "$BUILD"

# CFLAGS concerne le compilateur exécuté sous Windows.
# Les options destinées à libgcc sont séparées.
CFLAGS="${CFLAGS:--O1 -std=gnu89}" \
CXXFLAGS="${CXXFLAGS:--O1}" \
CFLAGS_FOR_TARGET="${CFLAGS_FOR_TARGET:--O2 -march=i386}" \
"$SRC/configure" \
    --build="$BUILD_TRIPLET" \
    --host="$HOST_TRIPLET" \
    --target="$TARGET" \
    --prefix="$PREFIX" \
    --with-sysroot="$PREFIX/$TARGET" \
    --enable-languages=c \
    --with-newlib \
    --without-headers \
    --with-gnu-as \
    --with-gnu-ld \
    --with-arch=i386 \
    --disable-bootstrap \
    --disable-nls \
    --disable-werror \
    --disable-multilib \
    --disable-shared \
    --disable-threads \
    --disable-lto \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --disable-libmudflap \
    --disable-decimal-float \
    --without-ppl \
    --without-cloog

echo make -j"$JOBS" "CC_FOR_BUILD=$CC_FOR_BUILD" all-gcc all-target-libgcc
echo make "CC_FOR_BUILD=$CC_FOR_BUILD" install-gcc install-target-libgcc

#"$PREFIX/bin/${TARGET}-gcc" -v