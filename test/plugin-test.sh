#!/bin/sh
# Plugin test on the phone (run as root, phone unlocked):
# shows keylog.qml as the focused app, presses Back through the plugin from a
# separate process, and checks udev doesn't call the device a keyboard.
# Everything goes to a root-owned folder in /tmp that the user can only read.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
U=phablet; UID_=$(id -u $U)
T=$(mktemp -d /tmp/gesture-pack-test.XXXXXX)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/imports/GesturePack"
cp "$HERE/../GesturePack/libGesturePack.so" "$HERE/../GesturePack/qmldir" "$T/imports/GesturePack/"
cp "$HERE/navtest.qml" "$HERE/keylog.qml" "$T/"
chmod -R a+rX,go-w "$T"

run_user() {
    runuser -u $U -- env XDG_RUNTIME_DIR=/run/user/$UID_ DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$UID_/bus "$@"
}
run_user env MIR_SOCKET=/run/user/$UID_/mir_socket QT_QPA_PLATFORM=ubuntumirclient GRID_UNIT_PX=25 \
    timeout 14 qmlscene "$T/keylog.qml" > "$T/keylog.out" 2>&1 &
sleep 4
run_user env QML2_IMPORT_PATH="$T/imports" QT_QPA_PLATFORM=offscreen timeout 10 qmlscene "$T/navtest.qml" > "$T/navtest.out" 2>&1 &
sleep 2.2
EV=$(grep -l "gesture-pack-keys" /sys/class/input/event*/device/name 2>/dev/null | head -1 | sed 's#/device/name##; s#.*/##')
if [ -n "$EV" ]; then
    echo "device: /dev/input/$EV"
    udevadm info /dev/input/$EV | grep -E "ID_INPUT" | sed 's/^/  /'
else
    echo "device: not found"
fi
wait
echo "--- plugin"; grep -E "NAVTEST|GesturePack|rror" "$T/navtest.out"
echo "--- focused app"; grep -E "KEY|SHORTCUT|rror" "$T/keylog.out"
