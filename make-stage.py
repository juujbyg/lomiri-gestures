"""Add what the three-finger gestures need to Lomiri's Stage/Stage.qml.

    python make-stage.py <stock Stage.qml> <out Stage.qml>

gestureSwitchApp(step) moves to the next or previous app, in the order the
apps were opened. gestureShowSpread() opens the app switcher.
"""
import sys

ANCHOR = "    function closeSpread() {\n"

FUNCTIONS = """    // Gesture Pack: three-finger gestures (MultiFingerGestures in Shell.qml).

    // Moves focus to the next (step = 1) or previous (step = -1) app.
    // Apps keep the order they were opened in, so repeated swipes walk
    // through all of them instead of bouncing between the last two.
    function gestureSwitchApp(step) {
        if (!spreadEnabled || appRepeater.count < 2) {
            return false;
        }
        if (spreadShown) {
            closeSpread();
        }
        var delegates = [];
        for (var i = 0; i < appRepeater.count; i++) {
            var item = appRepeater.itemAt(i);
            if (item && item.window) {
                delegates.push(item);
            }
        }
        if (delegates.length < 2) {
            return false;
        }
        delegates.sort(function(a, b) { return a.window.id - b.window.id; });
        var current = delegates.indexOf(priv.focusedAppDelegate);
        if (current < 0) {
            current = 0;
        }
        var next = (current + step + delegates.length) % delegates.length;
        delegates[next].activate();
        return true;
    }

    function gestureShowSpread() {
        if (!spreadEnabled || appRepeater.count === 0) {
            return false;
        }
        priv.goneToSpread = true;
        return true;
    }

"""


def main(stock, out):
    text = open(stock, "rb").read().decode()
    if "gestureSwitchApp" in text:
        sys.exit("already patched")
    needed = [ANCHOR, "id: appRepeater", "property bool goneToSpread", "focusedAppDelegate"]
    if text.count(ANCHOR) != 1 or any(n not in text for n in needed[1:]):
        sys.exit("Stage.qml doesn't look like the one this was made for")
    text = text.replace(ANCHOR, FUNCTIONS + ANCHOR)
    with open(out, "w", newline="\n") as f:
        f.write(text)
    print(f"wrote {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
