"""Make a patched Shell.qml that loads a navigation overlay.

    python make-shell.py <stock Shell.qml> <out Shell.qml>

The overlay is loaded through a Loader, so if it (or the LomiriNav plugin)
fails to load, only the overlay is missing and the shell keeps working.
"""
import sys


ANCHOR = """    Item {
        id: overlay
        z: 10

        anchors.fill: parent
"""

HOOK = """
        // LomiriNav: floating navigation (goals/lomiri-nav). Stock Lomiri has none.
        Loader {
            id: navOverlay
            objectName: "navOverlay"
            anchors.fill: parent
            source: "Components/NavOverlay.qml"
            // What the overlay needs from the shell, so it never reaches into ids.
            readonly property bool navAllowed: shell.mode !== "greeter"
                && !(greeter && greeter.shown)
                && !wizard.active && !tutorial.running
                && !stage.spreadShown && !launcher.drawerShown
                && !panel.indicators.shown
                && !panel.focusedSurfaceIsFullscreen
                && shell.topLevelSurfaceList.focusedWindow !== null
            readonly property real topInset: panel.panelHeight
            readonly property real keyboardHeight: inputMethod.visible
                ? Math.max(0, inputMethod.height - inputMethod.visibleRect.y) : 0
            function goHome() { shell.showHome() }
        }
"""


def main(stock, out):
    data = open(stock, "rb").read()
    text = data.decode()
    if text.count(ANCHOR) != 1:
        sys.exit("Shell.qml doesn't look like the one this was made for")
    text = text.replace(ANCHOR, ANCHOR + HOOK)
    with open(out, "w", newline="\n") as f:
        f.write(text)
    print(f"wrote {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
