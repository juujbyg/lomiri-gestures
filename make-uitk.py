"""Make the patched UI toolkit PageHeader.qml: StandardKey.Back (Alt+Left)
presses the visible page's back (or close) action in its header.

    python make-uitk.py <stock PageHeader.qml> <out PageHeader.qml>

Covers the toolkit's own back action (PageStack, AdaptivePageLayout) and the
back arrows apps put in leadingActionBar themselves. Only the first visible
leading action counts, and only if it looks like back or close, so a menu
("navigation-menu") is never opened by Back.
"""
import re
import sys


PATCH = """
    // LomiriNav: Back (Alt+Left, or a Back key) presses the back action
    // shown in this header. Only a visible header listens, so the top page wins.
    function __lomiriNavBackAction() {
        var list = leading.actions;
        for (var i = 0; i < list.length; i++) {
            var a = list[i];
            if (!a || !a.visible || !a.enabled) continue;
            var n = a.iconName || "";
            if (["back", "previous", "go-previous", "close"].indexOf(n) >= 0) return a;
            return null;
        }
        return null;
    }
    Shortcut {
        sequences: ["Alt+Left", "Back"]   // StandardKey.Back, spelled out: a list keeps only one of its bindings
        enabled: header.visible && header.enabled && leading.visible && header.__lomiriNavBackAction() !== null
        onActivated: {
            var a = header.__lomiriNavBackAction();
            if (a) a.trigger();
        }
    }
"""


def main(stock, out):
    data = open(stock, "rb").read()
    text = data.decode()
    if "__lomiriNavBackAction" in text:
        sys.exit("already patched")
    m = re.search(r"^import QtQuick 2\.(\d+)$", text, re.M)
    if not m:
        sys.exit("no QtQuick import found")
    if int(m.group(1)) < 9:                         # Shortcut.sequences needs QtQuick 2.9
        text = text[:m.start()] + "import QtQuick 2.9" + text[m.end():]
    anchor = '    styleName: "PageHeaderStyle"'
    if text.count(anchor) != 1 or not text.rstrip().endswith("}"):
        sys.exit("PageHeader.qml doesn't look like the one this was made for")
    i = text.index(anchor)
    text = text[:i] + PATCH.lstrip("\n") + "\n" + text[i:]
    with open(out, "w", newline="\n") as f:
        f.write(text)
    print(f"wrote {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
