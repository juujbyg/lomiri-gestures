"""Make the patched Shell.qml for the Gesture Pack.

    python make-shell.py <stock Shell.qml> <out Shell.qml>

Two changes:
 - a Loader for Components/GesturePackOverlay.qml (floating navigation), plus
   the screenshot helper. If the overlay (or the GesturePack plugin) fails to
   load, only the overlay is missing and the shell keeps working.
 - the four-finger tap area becomes MultiFingerGestures (three-finger swipes).
   With gestures off, or without the plugin, it behaves like stock: only the
   four-finger tap, which opens the app drawer.
Shell.qml itself never imports the plugin.
"""
import sys


OVERLAY_ANCHOR = """    Item {
        id: overlay
        z: 10

        anchors.fill: parent
"""

OVERLAY = """
        // Gesture Pack: floating navigation and screenshots. Stock Lomiri has neither.
        Loader {
            id: gesturePack
            objectName: "gesturePack"
            anchors.fill: parent
            source: "Components/GesturePackOverlay.qml"
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
            // Settings the shell reads back (false while the overlay isn't loaded).
            readonly property bool gesturesOn: item ? item.gesturesOn : false
            readonly property bool swipeScreenshotOn: item ? item.swipeScreenshotOn : false
            // True while a screenshot is being taken, so the overlay isn't in it.
            property bool hiding: false
            function goHome() { shell.showHome() }
            function screenshot() {
                if (hiding || shell.mode === "greeter") return
                hiding = true
                gesturePackShotDelay.start()
            }
        }
        Timer {
            id: gesturePackShotDelay
            interval: 250       // let the overlay and any gesture hint disappear first
            onTriggered: { itemGrabber.capture(shell); gesturePackShotDone.start() }
        }
        Timer {
            id: gesturePackShotDone
            interval: 500
            onTriggered: gesturePack.hiding = false
        }
"""

TAP_AREA = """        TouchGestureArea {
            anchors.fill: stage

            minimumTouchPoints: 4
            maximumTouchPoints: minimumTouchPoints

            readonly property bool recognisedPress: status == TouchGestureArea.Recognized &&
                                                    touchPoints.length >= minimumTouchPoints &&
                                                    touchPoints.length <= maximumTouchPoints
            property bool wasPressed: false

            onRecognisedPressChanged: {
                if (recognisedPress) {
                    wasPressed = true;
                }
            }

            onStatusChanged: {
                if (status !== TouchGestureArea.Recognized) {
                    if (status === TouchGestureArea.WaitingForTouch) {
                        if (wasPressed && !dragging) {
                            launcher.toggleDrawer(true);
                        }
                    }
                    wasPressed = false;
                }
            }
        }
"""

GESTURES = """        // Gesture Pack: three-finger gestures (Components/MultiFingerGestures.qml).
        // With them off, only the stock four-finger tap is left.
        MultiFingerGestures {
            id: multiFingerGestures
            objectName: "multiFingerGestures"
            anchors.fill: stage

            readonly property bool threeFinger: gesturePack.gesturesOn
            // In windowed mode three fingers move a window (WindowControlsOverlay).
            minimumTouchPoints: stage.mode === "windowed" || !threeFinger ? 4 : 3

            readonly property bool locked: shell.showingGreeter || wizard.active
            readonly property int appCount: shell.topLevelSurfaceList ? shell.topLevelSurfaceList.count : 0
            readonly property bool canSwitch: !locked && stage.spreadEnabled && appCount > 1

            hintFor: function(gesture, fingers) {
                if (locked || !threeFinger) return "";
                switch (gesture) {
                case "swipeLeft": return canSwitch ? i18n.tr("Next app") : "";
                case "swipeRight": return canSwitch ? i18n.tr("Previous app") : "";
                case "swipeUp": return stage.spreadEnabled && appCount > 0 && !stage.spreadShown ? i18n.tr("App switcher") : "";
                case "swipeDown":
                    if (stage.spreadShown) return i18n.tr("Close app switcher");
                    return gesturePack.swipeScreenshotOn ? i18n.tr("Screenshot") : "";
                }
                return "";
            }

            onTriggered: {
                if (locked) return;
                if (gesture === "tap") {
                    // The four-finger tap has always toggled the app drawer.
                    if (fingers === 4) launcher.toggleDrawer(true);
                    return;
                }
                if (!threeFinger) return;
                switch (gesture) {
                case "swipeLeft":
                case "swipeRight":
                    if (launcher.drawerShown) launcher.hide();
                    stage.gestureSwitchApp(gesture === "swipeLeft" ? 1 : -1);
                    break;
                case "swipeUp":
                    if (launcher.drawerShown) launcher.hide();
                    stage.gestureShowSpread();
                    break;
                case "swipeDown":
                    if (stage.spreadShown) stage.closeSpread();
                    else if (gesturePack.swipeScreenshotOn) gesturePack.screenshot();
                    break;
                }
            }
        }
"""


def main(stock, out):
    text = open(stock, "rb").read().decode()
    if "gesturePack" in text:
        sys.exit("already patched")
    if text.count(OVERLAY_ANCHOR) != 1 or text.count(TAP_AREA) != 1:
        sys.exit("Shell.qml doesn't look like the one this was made for")
    for name in ("gesturePack", "gesturePackShotDelay", "gesturePackShotDone", "multiFingerGestures"):
        if f"id: {name}\n" in text:
            sys.exit(f"Shell.qml already has an id {name}")
    text = text.replace(OVERLAY_ANCHOR, OVERLAY_ANCHOR + OVERLAY)
    text = text.replace(TAP_AREA, GESTURES)
    with open(out, "w", newline="\n") as f:
        f.write(text)
    print(f"wrote {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
