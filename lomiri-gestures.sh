#!/bin/bash
# Mac-style multi-finger gestures for Lomiri, until they're in Lomiri itself.
#
#   sudo ~/gestures/lomiri-gestures.sh on      turn them on (restarts the shell)
#   sudo ~/gestures/lomiri-gestures.sh reload  load new versions of the files (restarts the shell)
#   sudo ~/gestures/lomiri-gestures.sh off     back to the stock shell (restarts it)
#        ~/gestures/lomiri-gestures.sh status
#
# Nothing on the system is changed. "on" copies the shell's QML to /run, swaps
# in the three changed files and mounts the copy over /usr/share/lomiri. A
# reboot, or "off", brings the stock shell back. Restarting the shell closes
# open apps and shows the lock screen.
#
# It only runs on the Lomiri build the files were made from, and turns itself
# off again if the shell logs an error from the changed files.
set -u

HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
FILES="$HERE/files"
TARGET=/usr/share/lomiri
COPY=/run/lomiri-gestures
USER_NAME=phablet
UNIT=lomiri-full-greeter.service

# sha256 of the stock files these changes were made from
# (lomiri 0.5.0+0~20260910085057.5+ubports24.04.2~1.gbp0bd07c, 24.04-2.x build 283)
STOCK_SHELL=12509e4732b3403881ad4a0d0a4f725e8b942aa4fc20b057b2bce0c8323ed9cd
STOCK_STAGE=d6564642d8a17c4088a53f8a44c6706f2924656d6551dfb6abd9e72fc0ed9299

mounted() { findmnt -n "$TARGET" >/dev/null 2>&1; }

as_user() {
    local uid; uid=$(id -u "$USER_NAME")
    runuser -u "$USER_NAME" -- env XDG_RUNTIME_DIR=/run/user/$uid \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus "$@"
}

restart_shell() {
    echo "Restarting the shell; unlock the phone when it comes back."
    as_user systemctl --user restart "$UNIT"
}

need_root() {
    if [ "$(id -u)" != 0 ]; then
        echo "Run it with sudo: sudo $0 $1" >&2
        exit 1
    fi
}

turn_off() {
    if mounted; then
        umount "$TARGET" || umount -l "$TARGET"
    fi
    rm -rf "$COPY"
}

case "${1:-}" in
on)
    need_root on
    if mounted; then
        echo "Gestures are already on. Use 'off' first to reload them."
        exit 0
    fi
    shell_sum=$(sha256sum "$TARGET/Shell.qml" | cut -d' ' -f1)
    stage_sum=$(sha256sum "$TARGET/Stage/Stage.qml" | cut -d' ' -f1)
    if [ "$shell_sum" != "$STOCK_SHELL" ] || [ "$stage_sum" != "$STOCK_STAGE" ]; then
        echo "This Lomiri isn't the build the gesture files were made for" >&2
        echo "(probably after a system update). Nothing was changed." >&2
        exit 1
    fi
    for f in Shell.qml Stage/Stage.qml Components/MultiFingerGestures.qml; do
        [ -f "$FILES/$f" ] || { echo "Missing $FILES/$f" >&2; exit 1; }
    done

    rm -rf "$COPY"
    cp -a "$TARGET" "$COPY" || { rm -rf "$COPY"; exit 1; }
    cp "$FILES/Shell.qml" "$COPY/Shell.qml"
    cp "$FILES/Stage/Stage.qml" "$COPY/Stage/Stage.qml"
    cp "$FILES/Components/MultiFingerGestures.qml" "$COPY/Components/MultiFingerGestures.qml"
    chown -R root:root "$COPY"
    chmod -R a+rX,go-w "$COPY"
    mount --bind "$COPY" "$TARGET" || { rm -rf "$COPY"; exit 1; }
    mount -o remount,bind,ro "$TARGET" 2>/dev/null

    restart_shell
    sleep 20
    # Only the new shell's own messages: the old one logs TypeErrors while it
    # shuts down. Stock Lomiri also logs "Unable to assign PanelState..." from
    # Shell.qml at every start, so that one doesn't count.
    pid=$(as_user systemctl --user show -p MainPID --value "$UNIT")
    errors=$(as_user journalctl --user _PID="$pid" --no-pager -o cat 2>/dev/null |
             grep -E "lomiri/+(Shell\.qml|Stage/Stage\.qml|Components/MultiFingerGestures\.qml)" |
             grep -v "Unable to assign PanelState_QMLTYPE_")
    state=$(as_user systemctl --user is-active "$UNIT")
    if [ "$state" != active ] || [ -n "$errors" ]; then
        echo "The shell didn't take the change (state: $state). Going back to stock." >&2
        [ -n "$errors" ] && echo "$errors" | head -5 >&2
        turn_off
        restart_shell
        exit 1
    fi
    echo "Gestures are on until the next reboot."
    ;;
reload)
    # New versions of the files, with one shell restart instead of off + on.
    need_root reload
    if ! mounted || [ ! -d "$COPY" ]; then
        echo "Gestures are off; use 'on'." >&2
        exit 1
    fi
    cp "$FILES/Shell.qml" "$COPY/Shell.qml"
    cp "$FILES/Stage/Stage.qml" "$COPY/Stage/Stage.qml"
    cp "$FILES/Components/MultiFingerGestures.qml" "$COPY/Components/MultiFingerGestures.qml"
    restart_shell
    echo "Reloaded."
    ;;
off)
    need_root off
    if ! mounted && [ ! -d "$COPY" ]; then
        echo "Gestures are already off."
        exit 0
    fi
    turn_off
    restart_shell
    echo "Back to the stock shell."
    ;;
status)
    if mounted; then echo "on"; else echo "off"; fi
    ;;
*)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
