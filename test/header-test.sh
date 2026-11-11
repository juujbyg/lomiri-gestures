#!/bin/sh
# Runs headerback.qml as a real app window and presses Back (Alt+Left) three
# times through a separate uinput device. Run as root, phone unlocked, with
# lomiri-nav on (the PageHeader patch must be mounted).
# Expected: press 1 on page 4 (menu icon) does nothing; the app then pops page 4
# itself; press 2 uses page 3's app-made back; press 3 the toolkit's back -> page 1.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
U=phablet; UID_=$(id -u $U)
T=/home/$U/.cache/lomiri-nav-test
mkdir -p "$T"; cp "$HERE/headerback.qml" "$T/"; chown -R $U: "$T"
runuser -u $U -- env XDG_RUNTIME_DIR=/run/user/$UID_ MIR_SOCKET=/run/user/$UID_/mir_socket \
    QT_QPA_PLATFORM=ubuntumirclient GRID_UNIT_PX=25 timeout 28 qmlscene "$T/headerback.qml" > "$T/hb.out" 2>&1 &
sleep 5
python3 -I "$HERE/press.py" 4 4
wait
grep -E "HB|rror" "$T/hb.out"
