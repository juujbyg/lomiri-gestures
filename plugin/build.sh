#!/bin/sh
# Cross-build the GesturePack QML plugin for arm64 in the clickable image.
# On Windows: wsl sh ./build.sh   Output: ../GesturePack/libGesturePack.so
set -eu
cd "$(dirname "$0")"
mkdir -p out
docker run --rm -v "$PWD":/src clickable/amd64-ut24.04-1.x-arm64 bash -c '
set -e
cd /src
export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig
/usr/lib/qt5/bin/moc gesturepack.cpp -o gesturepack.moc
aarch64-linux-gnu-g++ -O2 -fPIC -shared -std=c++17 -Wall gesturepack.cpp -o out/libGesturePack.so \
    $(pkg-config --cflags --libs Qt5Qml Qt5Core)
rm -f gesturepack.moc
'
mkdir -p ../GesturePack && cp out/libGesturePack.so ../GesturePack/ && cp qmldir ../GesturePack/ && rm -rf out
ls -l ../GesturePack
