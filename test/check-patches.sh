#!/bin/sh
# PC check: make-*.py must turn the stock files into exactly test/expected/,
# and refuse to patch twice.
set -eu
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
python3 make-shell.py test/stock/Shell.qml "$T/Shell.qml" >/dev/null
python3 make-stage.py test/stock/Stage.qml "$T/Stage.qml" >/dev/null
python3 make-greeter.py test/stock/GreeterView.qml "$T/GreeterView.qml" >/dev/null
python3 make-uitk.py test/stock/PageHeader.qml "$T/PageHeader.qml" >/dev/null
python3 make-settings.py test/stock/GesturesPageComponent.qml "$T/GesturesPageComponent.qml" >/dev/null
python3 make-settings.py --dt2w test/stock/GesturesPageComponent.qml "$T/GesturesPageComponent-dt2w.qml" >/dev/null
for f in Shell.qml Stage.qml GreeterView.qml PageHeader.qml GesturesPageComponent.qml GesturesPageComponent-dt2w.qml; do
    cmp "$T/$f" "test/expected/$f" || { echo "FAIL: $f differs"; exit 1; }
done
for p in "make-shell.py Shell" "make-stage.py Stage" "make-greeter.py GreeterView" "make-uitk.py PageHeader" "make-settings.py GesturesPageComponent"; do
    set -- $p
    python3 "$1" "$T/$2.qml" "$T/again.qml" 2>/dev/null && { echo "FAIL: $1 patched twice"; exit 1; }
done
echo "patches OK"
