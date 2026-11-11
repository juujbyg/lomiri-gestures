#!/bin/sh
# PC check: make-*.py must turn the stock files into exactly test/expected/.
set -eu
cd "$(dirname "$0")/.."
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
python3 make-shell.py test/stock/Shell.qml "$T/Shell.qml" >/dev/null
python3 make-uitk.py test/stock/PageHeader.qml "$T/PageHeader.qml" >/dev/null
python3 make-settings.py test/stock/GesturesPageComponent.qml "$T/GesturesPageComponent.qml" >/dev/null
for f in Shell.qml PageHeader.qml GesturesPageComponent.qml; do
    cmp "$T/$f" "test/expected/$f" || { echo "FAIL: $f differs"; exit 1; }
done
python3 make-uitk.py "$T/PageHeader.qml" "$T/again.qml" 2>/dev/null && { echo "FAIL: patched twice"; exit 1; }
echo "patches OK"
