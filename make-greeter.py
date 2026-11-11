"""Add the camera and flashlight buttons to the lock screen's cover page.

    python make-greeter.py <stock Greeter/GreeterView.qml> <out GreeterView.qml>

They're loaded through a Loader from Components/GesturePackLockButtons.qml, so
if that (or the GesturePack plugin) fails to load, the lock screen is stock.
Being inside the cover page, they slide away with it.
"""
import sys

ANCHOR = """        Clock {
            id: clock
            anchors.centerIn: parent
        }
"""

BUTTONS = """
        // Gesture Pack: camera and flashlight in the bottom corners.
        Loader {
            id: gesturePackLockButtons
            objectName: "gesturePackLockButtons"
            anchors.fill: parent
            z: 10
            source: "../Components/GesturePackLockButtons.qml"
        }
"""


def main(stock, out):
    text = open(stock, "rb").read().decode()
    if "gesturePackLockButtons" in text:
        sys.exit("already patched")
    if text.count(ANCHOR) != 1 or text.count("    CoverPage {\n        id: coverPage\n") != 1:
        sys.exit("GreeterView.qml doesn't look like the one this was made for")
    # The clock must be the cover page's (not the PIN screen's).
    if text.index(ANCHOR) < text.index("id: coverPage"):
        sys.exit("GreeterView.qml doesn't look like the one this was made for")
    text = text.replace(ANCHOR, ANCHOR + BUTTONS)
    with open(out, "w", newline="\n") as f:
        f.write(text)
    print(f"wrote {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
