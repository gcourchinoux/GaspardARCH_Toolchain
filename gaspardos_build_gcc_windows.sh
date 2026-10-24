#!/usr/bin/env bash
set -euo pipefail

# Run from MSYS2 MinGW64. Build programs that RUN on GaspardOS.
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if (( $# > 1 )); then
  printf 'Usage: %s [gcc-source-directory]\n' "$0" >&2
  exit 1
fi
SOURCE_DIR="${1:-$PROJECT_DIR/gcc-4.6.4}"
if [[ ! -f "$SOURCE_DIR/configure" ]]; then
  printf 'GCC configure script not found: %s/configure\n' "$SOURCE_DIR" >&2
  exit 1
fi
SOURCE_DIR="$(cd -- "$SOURCE_DIR" && pwd)"
SYSROOT="${SYSROOT:-/c/projets/GaspardOS/newlib-gaspardos/gaspardos/build-gcc/sysroot/i386-unknown-elf}"
CRT_DIR="${CRT_DIR:-/c/projets/GaspardOS/newlib-gaspardos/gaspardos/build-gcc}"
export TARGET=i386-gaspardos
TOOLCHAIN_PREFIX="$PROJECT_DIR/build"
export PATH="$TOOLCHAIN_PREFIX/bin:$PATH"

BUILD_DIR="$PROJECT_DIR/build-gcc-native-gaspardos"
# Installation staging directory on Windows; runtime prefix on GaspardOS: /usr.
STAGING_DIR="$PROJECT_DIR/build-gcc-native-install"

for tool in gcc ar ranlib as ld nm readelf; do
  command -v "$TARGET-$tool" >/dev/null || {
    printf 'Missing cross tool: %s (expected in %s/bin)\n' "$TARGET-$tool" "$TOOLCHAIN_PREFIX" >&2
    exit 1
  }
done

# Build-time generators run on Windows, unlike the resulting compiler.
# Old GCC/GMP require GNU89 with current MinGW GCC.
LEGACY_CFLAGS="-std=gnu89 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion"
export CC_FOR_BUILD="${CC_FOR_BUILD:-gcc $LEGACY_CFLAGS}"
export CFLAGS_FOR_BUILD="${CFLAGS_FOR_BUILD:--O2 $LEGACY_CFLAGS}"
command -v "${CC_FOR_BUILD%% *}" >/dev/null || {
  printf 'Missing build compiler: %s\n' "$CC_FOR_BUILD" >&2
  exit 1
}

# Native Windows GCC needs Windows paths, including in configure's saved flags.
SYSROOT="$(cd -- "$SYSROOT" && pwd)"
COMPILER_SYSROOT="$(cygpath -m "$SYSROOT")"
CRT_DIR="$(cd -- "$CRT_DIR" && pwd)"
COMPILER_CRT_DIR="$(cygpath -m "$CRT_DIR")"
for file in crt0.o start.o; do
  if [[ ! -f "$CRT_DIR/$file" ]]; then
    printf 'Missing startup object: %s/%s\n' "$CRT_DIR" "$file" >&2
    exit 1
  fi
done
LINKER_SCRIPT="${LINKER_SCRIPT:-$CRT_DIR/../link.ld}"
if [[ ! -f "$LINKER_SCRIPT" ]]; then
  printf 'Missing linker script: %s\n' "$LINKER_SCRIPT" >&2
  exit 1
fi
COMPILER_LINKER_SCRIPT="$(cygpath -am "$LINKER_SCRIPT")"
for file in lib/libc.a lib/libm.a lib/libgaspardos.a; do
  if [[ ! -f "$SYSROOT/$file" ]]; then
    printf 'Missing sysroot file: %s/%s\n' "$SYSROOT" "$file" >&2
    exit 1
  fi
done

# Refresh startup objects: the current ABI forwards RUN arguments to main.
PORT_DIR="$(cd -- "$CRT_DIR/.." && pwd)"
"$TARGET-gcc" -c "$(cygpath -am "$PORT_DIR/crt0.S")" -o "$COMPILER_CRT_DIR/crt0.o"
"$TARGET-gcc" -std=gnu99 -O2 -ffreestanding -fno-builtin -fPIE \
  -fvisibility=hidden -fomit-frame-pointer -fno-stack-protector -mno-sse -mno-mmx \
  -isystem "$COMPILER_SYSROOT/include" -c "$(cygpath -am "$PORT_DIR/start.c")" \
  -o "$COMPILER_CRT_DIR/start.o"

mkdir -p "$BUILD_DIR" "$STAGING_DIR"
cd "$BUILD_DIR"

# Keep headers available to sub-configures launched later by make.
export CPPFLAGS="-isystem $COMPILER_SYSROOT/include ${CPPFLAGS:-}"
# Newlib formatted I/O needs libm; rescan the static libraries together.
export LIBS="-Wl,--start-group -lc -lm -lgaspardos -lgcc -Wl,--end-group ${LIBS:-}"

export CFLAGS="-O2 -std=gnu89 -fPIE -fvisibility=hidden -fomit-frame-pointer -fno-stack-protector -mno-sse -mno-mmx ${CFLAGS:-}" 
CC="$TARGET-gcc --sysroot=$COMPILER_SYSROOT -B$COMPILER_CRT_DIR/ -B$COMPILER_SYSROOT/lib/" \
AR="$TARGET-ar" \
RANLIB="$TARGET-ranlib" \
AS="$TARGET-as" \
LD="$TARGET-ld" \
NM="$TARGET-nm" \
LDFLAGS="-pie -nostartfiles -Wl,-z,notext,--no-undefined,--build-id=none -Wl,-T,$COMPILER_LINKER_SCRIPT,$COMPILER_CRT_DIR/crt0.o,$COMPILER_CRT_DIR/start.o -L$COMPILER_SYSROOT/lib ${LDFLAGS:-}" \
"$SOURCE_DIR/configure" \
  --build=x86_64-w64-mingw32 \
  --host="$TARGET" \
  --target="$TARGET" \
  --prefix=/usr \
  --with-sysroot=/ \
  --with-build-sysroot="$COMPILER_SYSROOT" \
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
  --disable-plugin \
  --disable-libssp \
  --disable-libgomp \
  --disable-libquadmath \
  --disable-libmudflap \
  --disable-decimal-float \
  --without-ppl \
  --without-cloog

# Build only the compiler: target libraries are supplied by the GaspardOS SDK.
# A Windows path must never become the installed compiler's runtime sysroot.
make clean
make -j"${JOBS:-4}" "CC_FOR_BUILD=$CC_FOR_BUILD" all-gcc
make "CC_FOR_BUILD=$CC_FOR_BUILD" DESTDIR="$STAGING_DIR" install-gcc

# The kernel accepts ET_EXEC; crt0 performs the PIE relocations itself.
# Patch only the installed programs, preserving build outputs for make/libtool.
while IFS= read -r -d '' program; do
  magic="$(od -An -tx1 -N4 "$program" | tr -d ' \n\r')"
  [[ "$magic" == 7f454c46 ]] || continue
  # Older readelf cannot decode .rel.dyn when .dynsym is empty.
  if ! "$TARGET-readelf" -SW "$program" | grep '\.rel\.dyn.*REL.* A ' >/dev/null; then
    printf 'Missing PIE relocations: %s\n' "$program" >&2
    exit 1
  fi
  printf '\002\000' | dd of="$program" bs=1 seek=16 conv=notrunc 2>/dev/null
done < <(find "$STAGING_DIR/usr/bin" "$STAGING_DIR/usr/libexec/gcc" -type f -print0)

printf '\nGaspardOS GCC installed in: %s/usr (bin and libexec/gcc)\n' "$STAGING_DIR"
