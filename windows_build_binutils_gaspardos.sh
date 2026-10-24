export TARGET=i386-gaspardos
export PREFIX=/c/projets/compilo-gaspardos/build

cd binutils-2.25 && mkdir build-binutils-full &&
cd build-binutils-full &&

LDFLAGS="-static" ../configure \
  --build=x86_64-w64-mingw32 \
  --host=x86_64-w64-mingw32 \
  --target="$TARGET" \
  --prefix="$PREFIX" \
  --with-sysroot="$PREFIX/$TARGET" \
  --disable-nls \
  --disable-werror \
  --disable-shared \
  --disable-plugins \
  --disable-gold \
  --disable-gprof \
  --disable-install-libbfd &&

make -j4 &&
make install