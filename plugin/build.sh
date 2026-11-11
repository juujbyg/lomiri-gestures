#!/bin/sh
# Cross-build the LomiriNav QML plugin for arm64 in the clickable image.
# On Windows: wsl sh ./build.sh   Output: LomiriNav/libLomiriNav.so
set -eu
cd "$(dirname "$0")"
mkdir -p LomiriNav
docker run --rm -v "$PWD":/src clickable/amd64-ut24.04-1.x-arm64 bash -c '
set -e
cd /src
export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig
/usr/lib/qt5/bin/moc navkeys.cpp -o navkeys.moc
aarch64-linux-gnu-g++ -O2 -fPIC -shared -std=c++17 -Wall navkeys.cpp -o LomiriNav/libLomiriNav.so \
    $(pkg-config --cflags --libs Qt5Qml Qt5Core)
rm -f navkeys.moc
'
mkdir -p ../LomiriNav && cp LomiriNav/libLomiriNav.so qmldir ../LomiriNav/ && rm -rf LomiriNav
ls -l ../LomiriNav
