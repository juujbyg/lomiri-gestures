#!/bin/bash
# Lomiri Gestures & Shortcuts: floating Back button or Back/Home/Apps bar, three-finger
# gestures, screenshots, camera and flashlight on the lock screen, and double
# tap to wake where the phone supports it.
# Choose what you want in System Settings > Gestures.
#
#   sudo ./lomiri-gestures.sh on          try it until the next reboot (restarts the shell)
#   sudo ./lomiri-gestures.sh off         back to stock now (restarts the shell)
#   sudo ./lomiri-gestures.sh install     keep it across reboots (restarts the shell)
#   sudo ./lomiri-gestures.sh uninstall   remove everything (restarts the shell)
#        ./lomiri-gestures.sh mode off|button|bar
#        ./lomiri-gestures.sh status
#
# The read-only system is never changed. Each start, the changes are made to
# copies in /run, from this phone's own files, and mounted over the originals:
#  - Lomiri's Shell.qml and Stage/Stage.qml: the floating navigation, the
#    three-finger gestures and screenshots; Greeter/GreeterView.qml: camera and
#    flashlight on the lock screen,
#  - the UI toolkit's PageHeader.qml learns the Back shortcut (Alt+Left),
#  - System Settings > Gestures gets the choices.
# A part whose file doesn't look as expected is left out. The GesturePack QML
# plugin, which presses the keys, goes to a small root-owned tmpfs in /run
# (/run itself is noexec). As root, this never writes in the user's home: the
# settings file is written as the user.
set -u

HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
INSTALL_DIR=/root/lomiri-gestures
BOOT_UNIT=/etc/systemd/system/lomiri-gestures.service
DT2W_UNIT=gesture-pack-dt2w.service
TARGET=/usr/share/lomiri
RUN=/run/gesture-pack
COPY=$RUN/shell
LIB=$RUN-lib                      # tmpfs mounted without noexec, for the plugin
PAGEHEADER=/usr/lib/aarch64-linux-gnu/qt5/qml/Lomiri/Components/1.3/PageHeader.qml
SETTINGS_PAGE=/usr/share/lomiri-system-settings/qml-plugins/gestures/PageComponent.qml
USER_NAME=phablet
USER_HOME=/home/$USER_NAME
UNIT=lomiri-full-greeter.service
SETTINGS_FILE=$USER_HOME/.config/lomiri-gesture-pack/settings.conf
DROPIN_DIR=/run/systemd/user/$UNIT.d

uid() { id -u "$USER_NAME"; }

as_user() {
    runuser -u "$USER_NAME" -- env XDG_RUNTIME_DIR=/run/user/$(uid) \
        DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(uid)/bus "$@"
}

need_root() {
    if [ "$(id -u)" != 0 ]; then echo "Run it with sudo: sudo $0 ${1:-}" >&2; exit 1; fi
}

shell_mounted() { findmnt -n "$TARGET" >/dev/null 2>&1; }
ours() { [ -f "$COPY/.gesture-pack" ]; }
shell_pid() { as_user systemctl --user show -p MainPID --value "$UNIT"; }
session_up() { [ -d "/run/user/$(uid)" ] && [ "$(shell_pid)" != 0 ]; }

# Another double-tap service (an older dt2w setup) would fight over the panel.
other_dt2w() {
    systemctl list-units --type=service --state=active --no-legend 2>/dev/null |
        awk '{print $1}' | grep -i dt2w | grep -vx "$DT2W_UNIT" | head -1
}
dt2w_ok() { sh "$HERE/addons/dt2w" supported && [ -z "$(other_dt2w)" ]; }

# Restart the shell and wait for the new one. Lomiri can take over a minute to
# stop on SIGTERM (systemd only kills it after 90 s), so it gets 10 s, then KILL.
restart_shell() {
    session_up || return 0
    echo "Restarting the shell; open apps close. Unlock the phone when it comes back."
    local old; old=$(shell_pid)
    as_user systemctl --user daemon-reload
    as_user systemctl --user --no-block restart "$UNIT"
    for i in $(seq 1 10); do [ "$(shell_pid)" != "$old" ] && break; sleep 1; done
    if [ "$(shell_pid)" = "$old" ]; then as_user systemctl --user kill --signal=SIGKILL "$UNIT"; fi
    for i in $(seq 1 60); do
        local pid; pid=$(shell_pid)
        if [ "$pid" != "$old" ] && [ "$pid" != 0 ] && [ "$(as_user systemctl --user is-active "$UNIT")" = active ]; then
            return 0
        fi
        sleep 1
    done
    echo "The shell didn't come back within 70 s." >&2
    return 1
}

# Loads a page with a PageHeader offscreen; prints any error from PageHeader.qml.
pageheader_errors() {
    local t; t=$(mktemp -d)
    cat > "$t/check.qml" <<'EOF'
import QtQuick 2.12
import Lomiri.Components 1.3
MainView {
    width: 400; height: 600
    PageStack { id: s; Component.onCompleted: { push(p1); push(p2) } }
    Page { id: p1; visible: false; header: PageHeader { title: "1" } }
    Page { id: p2; visible: false; header: PageHeader { title: "2" } }
    Timer { interval: 300; running: true; onTriggered: Qt.quit() }
}
EOF
    chmod -R a+rX "$t"
    runuser -u "$USER_NAME" -- env HOME=$USER_HOME XDG_RUNTIME_DIR="$t" QT_QPA_PLATFORM=offscreen \
        timeout 20 qmlscene "$t/check.qml" 2>&1 | grep -E "PageHeader\.qml" | head -3
    rm -rf "$t"
}

undo_mounts() {
    if systemctl is-active --quiet "$DT2W_UNIT"; then
        systemctl stop "$DT2W_UNIT"
        sh "$RUN/dt2w" disarm 2>/dev/null
    fi
    if shell_mounted && ours; then umount "$TARGET" || umount -l "$TARGET"; fi
    for f in "$PAGEHEADER" "$SETTINGS_PAGE"; do
        if mountpoint -q "$f" && findmnt -n -o SOURCE "$f" | grep -q gesture-pack; then umount "$f"; fi
    done
    rm -f "$DROPIN_DIR/gesture-pack.conf"; rmdir "$DROPIN_DIR" 2>/dev/null
    rm -rf "$RUN"
    # The running shell may still map the plugin: detach now, freed when it exits.
    if mountpoint -q "$LIB"; then umount "$LIB" 2>/dev/null || umount -l "$LIB"; fi
    rmdir "$LIB" 2>/dev/null
    true
}

# Make the patched copies from this phone's own files and mount them. No restart.
mount_all() {
    if shell_mounted; then
        if ours; then echo "Already on."; return 0; fi
        echo "Something else (an older lomiri-gestures or lomiri-nav?) is mounted over $TARGET; turn it off first." >&2
        return 1
    fi
    [ -f "$HERE/GesturePack/libGesturePack.so" ] || { echo "Missing $HERE/GesturePack/libGesturePack.so" >&2; return 1; }
    rm -rf "$RUN"; mkdir -p "$RUN"

    # The plugin, on its own root-owned tmpfs, so the shell only loads what
    # root put there. /run is noexec, which would stop the library loading.
    if mountpoint -q "$LIB"; then umount "$LIB" 2>/dev/null || umount -l "$LIB"; fi
    mkdir -p "$LIB"
    mount -t tmpfs -o mode=0755,size=4m,nosuid,nodev gesture-pack-lib "$LIB" || { undo_mounts; return 1; }
    mkdir "$LIB/GesturePack"
    cp "$HERE/GesturePack/libGesturePack.so" "$HERE/GesturePack/qmldir" "$LIB/GesturePack/"
    chmod -R a+rX,go-w "$LIB"
    mount -o remount,ro,nosuid,nodev "$LIB" 2>/dev/null

    # The shell. Without this part nothing works, so a failure stops here.
    cp -a "$TARGET" "$COPY" || { undo_mounts; return 1; }
    if ! python3 -I "$HERE/make-shell.py" "$TARGET/Shell.qml" "$COPY/Shell.qml" >/dev/null ||
       ! python3 -I "$HERE/make-stage.py" "$TARGET/Stage/Stage.qml" "$COPY/Stage/Stage.qml" >/dev/null; then
        echo "Lomiri's Shell.qml or Stage.qml has changed in a way this doesn't know; nothing was changed." >&2
        undo_mounts; return 1
    fi
    cp "$HERE/files/Components/GesturePackOverlay.qml" "$HERE/files/Components/MultiFingerGestures.qml" \
        "$HERE/files/Components/GesturePackLockButtons.qml" "$COPY/Components/"
    # Camera and flashlight on the lock screen: optional, so a mismatch only skips it.
    if ! python3 -I "$HERE/make-greeter.py" "$TARGET/Greeter/GreeterView.qml" "$COPY/Greeter/GreeterView.qml" >/dev/null; then
        cp "$TARGET/Greeter/GreeterView.qml" "$COPY/Greeter/GreeterView.qml"
        echo "The lock screen has changed; camera and flashlight there are left out." >&2
    fi
    echo gesture-pack > "$COPY/.gesture-pack"
    chown -R root:root "$COPY"; chmod -R a+rX,go-w "$COPY"
    mount --bind "$COPY" "$TARGET" || { undo_mounts; return 1; }
    mount -o remount,bind,ro "$TARGET" 2>/dev/null

    # Back for UI toolkit apps. One file: /run is noexec, so overlaying the
    # folder would hide the toolkit's plugin. Checked before it's kept.
    if python3 -I "$HERE/make-uitk.py" "$PAGEHEADER" "$RUN/PageHeader.qml" >/dev/null; then
        chmod 644 "$RUN/PageHeader.qml"
        mount --bind "$RUN/PageHeader.qml" "$PAGEHEADER"
        errors=$(pageheader_errors)
        if [ -n "$errors" ]; then
            umount "$PAGEHEADER"
            echo "The Back fix for apps failed its check and is left out:" >&2
            echo "$errors" >&2
        fi
    else
        echo "The UI toolkit's PageHeader.qml has changed; Back works only where apps support Alt+Left." >&2
    fi

    # Double tap to wake, on phones whose touch panel supports it. It runs
    # from a root-owned copy and follows the user's setting.
    local dt2w_flag=""
    if dt2w_ok; then
        cp "$HERE/addons/dt2w" "$RUN/dt2w"; chmod 644 "$RUN/dt2w"
        systemctl reset-failed "$DT2W_UNIT" 2>/dev/null
        if systemd-run --no-block --unit="$DT2W_UNIT" --description="Lomiri Gestures: double tap to wake" \
               -p Restart=always -p RestartSec=5 /bin/sh "$RUN/dt2w" watch >/dev/null 2>&1; then
            dt2w_flag=--dt2w
        fi
    elif [ -n "$(other_dt2w)" ]; then
        echo "$(other_dt2w) is already handling double tap to wake, so Lomiri Gestures leaves it alone." >&2
    fi

    # The choices in System Settings > Gestures.
    if python3 -I "$HERE/make-settings.py" $dt2w_flag "$SETTINGS_PAGE" "$RUN/settings-page.qml" >/dev/null; then
        chmod 644 "$RUN/settings-page.qml"
        mount --bind "$RUN/settings-page.qml" "$SETTINGS_PAGE"
    else
        echo "System Settings' Gestures page has changed; use '$0 mode' instead." >&2
    fi

    # Only the shell gets the plugin's import path. /run/systemd/user is in the
    # user manager's search path, root-owned, and gone at reboot.
    mkdir -p "$DROPIN_DIR"
    printf '[Service]\nEnvironment=QML2_IMPORT_PATH=%s\n' "$LIB" > "$DROPIN_DIR/gesture-pack.conf"
    chmod 644 "$DROPIN_DIR/gesture-pack.conf"
    return 0
}

# Restart the shell and go back to stock if it logs an error from our files.
restart_and_check() {
    restart_shell || true
    session_up || return 0
    sleep 15
    local pid errors state
    pid=$(shell_pid)
    errors=$(as_user journalctl --user _PID="$pid" --no-pager -o cat 2>/dev/null |
             grep -E "lomiri/+(Shell\.qml|Stage/Stage\.qml|Greeter/GreeterView\.qml|Components/(GesturePackOverlay|MultiFingerGestures|GesturePackLockButtons)\.qml)|GesturePack" |
             grep -v "Unable to assign PanelState_QMLTYPE_")
    state=$(as_user systemctl --user is-active "$UNIT")
    if [ "$state" != active ] || [ -n "$errors" ]; then
        echo "The shell didn't take the change (state: $state). Going back to stock." >&2
        [ -n "$errors" ] && echo "$errors" | head -5 >&2
        undo_mounts
        restart_shell
        return 1
    fi
}

# Writes the style into the settings file. Runs as the phone's user.
write_mode() {
    local f=$2
    mkdir -p "$(dirname "$f")" || return 1
    [ -f "$f" ] || printf '[General]\n' > "$f" || return 1
    # sed -i replaces the file, which the shell's plugin notices.
    if grep -q '^mode=' "$f"; then sed -i "s/^mode=.*/mode=$1/" "$f"
    else sed -i "s/^\[General\]$/[General]\nmode=$1/" "$f"; fi
}

set_mode() {
    case "$1" in off|button|bar) ;; *) echo "mode is off, button or bar" >&2; exit 2 ;; esac
    if [ "$(id -u)" = 0 ]; then
        # Root never writes in the user's home: do it as the user.
        runuser -u "$USER_NAME" -- bash -c "$(declare -f write_mode)"'; write_mode "$1" "$2"' _ "$1" "$SETTINGS_FILE" || exit 1
    else
        write_mode "$1" "$SETTINGS_FILE" || exit 1
    fi
    echo "mode: $1"
}

case "${1:-}" in
on)
    need_root on
    mount_all || exit 1
    restart_and_check || exit 1
    echo "On until the next reboot. Choose what you want in System Settings > Gestures."
    ;;
off)
    need_root off
    undo_mounts
    restart_shell
    echo "Off; the stock shell is back."
    ;;
mount)
    # Used by the boot service, before the shell starts.
    need_root mount
    mount_all
    ;;
install)
    need_root install
    if [ "$HERE" != "$INSTALL_DIR" ]; then
        rm -rf "$INSTALL_DIR"; mkdir -p "$INSTALL_DIR"
        cp -r "$HERE/lomiri-gestures.sh" "$HERE"/make-*.py "$HERE/GesturePack" "$HERE/files" "$HERE/addons" "$INSTALL_DIR/"
        chown -R root:root "$INSTALL_DIR"; chmod -R go-w "$INSTALL_DIR"; chmod 755 "$INSTALL_DIR/lomiri-gestures.sh"
    fi
    cat > "$BOOT_UNIT" <<EOF
[Unit]
Description=Lomiri Gestures & Shortcuts for the Lomiri shell
After=local-fs.target
Before=lightdm.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$INSTALL_DIR/lomiri-gestures.sh mount
ExecStop=/bin/true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable lomiri-gestures.service
    # Already on needs no restart: while running, everything is used from /run.
    if ! (shell_mounted && ours); then
        "$INSTALL_DIR/lomiri-gestures.sh" on || { systemctl disable lomiri-gestures.service; rm -f "$BOOT_UNIT"; exit 1; }
    fi
    echo "Installed: it comes back after every reboot. Remove it with: sudo $INSTALL_DIR/lomiri-gestures.sh uninstall"
    ;;
uninstall)
    need_root uninstall
    systemctl disable lomiri-gestures.service 2>/dev/null
    rm -f "$BOOT_UNIT"; systemctl daemon-reload
    undo_mounts
    restart_shell
    runuser -u "$USER_NAME" -- rm -rf "$(dirname "$SETTINGS_FILE")"
    [ -d "$INSTALL_DIR" ] && echo "Removed. Its files are still in $INSTALL_DIR; delete them with: sudo rm -r $INSTALL_DIR"
    ;;
mode)
    set_mode "${2:-}"
    ;;
status)
    if shell_mounted && ours; then echo "on"; else echo "off"; fi
    mountpoint -q "$PAGEHEADER" && echo "Back fix for UI toolkit apps: on"
    mountpoint -q "$SETTINGS_PAGE" && echo "System Settings choices: on"
    systemctl is-active --quiet "$DT2W_UNIT" && echo "double tap to wake service: running ($(sh "$HERE/addons/dt2w" status))"
    [ -f "$BOOT_UNIT" ] && echo "installed (starts at boot)"
    [ -r "$SETTINGS_FILE" ] && echo "settings: $(grep -vE '^\[|^$' "$SETTINGS_FILE" | tr '\n' ' ')"
    true
    ;;
*)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 2 ;;
esac
