#!/usr/bin/env bash

set -exuo pipefail

# === Setup cross-compilation toolchain ===

# We will need to install some arm packages on our x86_64 system later on
dpkg --add-architecture armel
apt-get update

apt-get install -y \
    binutils-arm-linux-gnueabi \
    gcc-arm-linux-gnueabi \
    g++-arm-linux-gnueabi

# Native ldd can't be ran on cross-compiled binaries, so we use xldd from the crosstool-ng project
cp /repo/3rd-party/xldd/xldd.sh /usr/bin/arm-linux-gnueabi-ldd
chmod +x /usr/bin/arm-linux-gnueabi-ldd

# Cmake toolchain file https://cmake.org/cmake/help/v3.1/manual/cmake-toolchains.7.html
echo "
    SET(CMAKE_SYSTEM_NAME Linux)

    SET(CMAKE_C_COMPILER   /usr/bin/arm-linux-gnueabi-gcc)
    SET(CMAKE_CXX_COMPILER /usr/bin/arm-linux-gnueabi-g++)
    SET(CMAKE_AR           /usr/bin/arm-linux-gnueabi-ar CACHE FILEPATH "Archiver")

    SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
    SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
" > /usr/local/share/arm-linux-gnueabi.cmake


# === Cross-compile our app to arm ===

apt-get install -y \
    cmake \
    make \
    qtbase5-dev-tools \
    qt5-default

apt-get install -y \
    qtbase5-dev:armel

cd /repo
rm -rf ./build
mkdir build
cd build
cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_TOOLCHAIN_FILE=/usr/local/share/arm-linux-gnueabi.cmake
make -j2
make DESTDIR=output install -j2


# === Build x86_64 linuxdeployqt ===

apt-get install -y \
    git \
    qt5-default \
    qtbase5-dev \
    qtbase5-dev-tools \
    g++ \
    gcc \
    make

git clone https://github.com/probonopd/linuxdeployqt linuxdeployqt
cd linuxdeployqt
git checkout 26ba6229697bcc61990da98889d2ea425f37aca7
qmake
make -j2
make install -j2
cd ..
rm -rf ./linuxdeployqt


# === Build arm AppImageKit ===

apt-get install -y \
    git \
    automake \
    autoconf \
    libtool \
    make \
    gcc \
    g++ \
    desktop-file-utils \
    cmake \
    patch \
    wget \
    xxd \
    patchelf

apt-get install -y \
    libfuse-dev:armel \
    liblzma-dev:armel \
    libglib2.0-dev:armel \
    libssl-dev:armel \
    libinotifytools0-dev:armel \
    liblz4-dev:armel \
    libcairo-dev:armel \
    libarchive-dev:armel \
    libgtest-dev:armel

# Wordaround a bug in AppImageKit when using system XZ
rm /usr/lib/arm-linux-gnueabi/liblzma.so

# Debian distributed gtest in a source form, we have to built it ourselves
cd /usr/src/gtest
cmake . \
    -DCMAKE_TOOLCHAIN_FILE=/usr/local/share/arm-linux-gnueabi.cmake
make install -j2
cd -

git clone --recursive https://github.com/AppImage/AppImageKit AppImageKit
cd AppImageKit
git checkout 5aea3b0c8ff56f0820c70c8499f9c67a38d2322c
# Fix the sript to use the arm toolchain
sed -i "s|<SOURCE_DIR>/configure |<SOURCE_DIR>/configure --host=arm-linux-gnueabi |" cmake/dependencies.cmake
sed -i "s|gcc|/usr/bin/arm-linux-gnueabi-gcc|" src/build-runtime.sh.in
sed -i "s|ld |/usr/bin/arm-linux-gnueabi-ld |" src/build-runtime.sh.in
sed -i "s|objcopy |/usr/bin/arm-linux-gnueabi-objcopy |" src/build-runtime.sh.in
sed -i "s|readelf |/usr/bin/arm-linux-gnueabi-readelf |" src/build-runtime.sh.in
sed -i "s|strip|/usr/bin/arm-linux-gnueabi-strip|" src/build-runtime.sh.in
sed -i "s|objdump |/usr/bin/arm-linux-gnueabi-objdump |" src/build-runtime.sh.in
mkdir build
cd build
# Tell pkg-config to return arm packages instead of x86_64
export PKG_CONFIG_LIBDIR=/usr/lib/arm-linux-gnueabi/pkgconfig:/usr/share/pkgconfig
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=/usr/local/share/arm-linux-gnueabi.cmake \
    -DUSE_SYSTEM_XZ=ON \
    -DUSE_SYSTEM_INOTIFY_TOOLS=ON \
    -DUSE_SYSTEM_LIBARCHIVE=ON \
    -DUSE_SYSTEM_GTEST=ON
# Build fails when using more than 1 job
make VERBOSE=1 -j1
make install -j2
cd ../..
rm -rf ./AppImageKit


# === Create arm AppImage for our arm app ===

# Replace ldd with a wrapper for /usr/bin/arm-linux-gnueabi-ldd
echo '
#!/bin/sh
/usr/bin/arm-linux-gnueabi-ldd --root / "$@"
' > /usr/bin/ldd
chmod +x /usr/bin/ldd

/usr/lib/x86_64-linux-gnu/qt5/bin/linuxdeployqt output/usr/share/applications/my_app.desktop -bundle-non-qt-libs -appimage -no-strip -qmake=/usr/lib/arm-linux-gnueabi/qt5/bin/qmake

# Check architecture of the binaries, all should be arm
apt-get install -y \
    file
file output/usr/lib/*
file output/usr/bin/*
file *.AppImage
