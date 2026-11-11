"""Add the Gesture Pack's choices to System Settings > Gestures.

    python make-settings.py [--dt2w] <stock PageComponent.qml> <out PageComponent.qml>

Navigation (Off, Back button, Back/Home/Apps), a Screenshot button on the bar,
three-finger gestures, three fingers down for a screenshot, and camera and
flashlight on the lock screen. With --dt2w
(only when this phone's touch panel supports it), also double tap to wake.

The choices go to ~/.config/lomiri-gesture-pack/settings.conf, the file the
shell's GesturePack plugin (and the double-tap service) watch, so changes show
at once.
"""
import sys

SETTINGS_FILE = "/home/phablet/.config/lomiri-gesture-pack/settings.conf"

IMPORT_AFTER = "import GSettings 1.0\n"
IMPORT = "import Qt.labs.settings 1.1 as GesturePackLabs\n"

ANCHOR = """                text: i18n.tr("Allow editing screenshots when pressing Vol+ & Vol-.")
                wrapMode: Text.WordWrap
            }
"""

# A switch row bound to one setting, like the page's own switches.
SWITCH = """
            SettingsListItems.Standard {
                id: %(id)sRow
                text: %(text)s%(extra)s
                Switch {
                    objectName: "%(id)s"
                    property bool serverChecked: packSettings.%(key)s
                    onServerCheckedChanged: checked = serverChecked
                    Component.onCompleted: checked = serverChecked
                    onTriggered: packSettings.%(key)s = checked
                }
                showDivider: false
            }

            Label {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: units.gu(2)
                    rightMargin: units.gu(2)
                }
                text: %(help)s
                wrapMode: Text.WordWrap
                visible: %(id)sRow.visible
                opacity: %(id)sRow.enabled ? 1 : 0.5
            }
"""


def switch(id, key, text, help, extra=""):
    return SWITCH % dict(id=id, key=key, text=text, help=help, extra=extra)


def section(dt2w):
    out = """
            // Gesture Pack (github.com/juujbyg/lomiri-gestures)
            GesturePackLabs.Settings {
                id: packSettings
                fileName: "%s"
                property string mode: "button"
                property bool barScreenshot: true
                property bool gestures: true
                property bool swipeScreenshot: true
                property bool doubleTapWake: false
                property bool lockButtons: true
            }

            ListItem.Standard {
                height: units.gu(2)
                showDivider: true
            }

            SettingsItemTitle {
                text: i18n.tr("Navigation")
            }

            OptionSelector {
                id: navSelector
                objectName: "navMode"
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: units.gu(2)
                    rightMargin: units.gu(2)
                }
                expanded: true
                readonly property var modes: ["off", "button", "bar"]
                model: [
                    i18n.tr("Off"),
                    i18n.tr("Back button"),
                    i18n.tr("Back, Home and Apps")
                ]
                selectedIndex: Math.max(0, modes.indexOf(packSettings.mode))
                onDelegateClicked: packSettings.mode = modes[index]
            }

            Label {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: units.gu(2)
                    rightMargin: units.gu(2)
                    topMargin: units.gu(1)
                }
                text: i18n.tr("Floating navigation over apps, in thumb reach. Drag it to move it; press and hold it to take a screenshot, switch style or hide it.")
                wrapMode: Text.WordWrap
            }
""" % SETTINGS_FILE
    out += switch("packBarScreenshot", "barScreenshot", 'i18n.tr("Screenshot button on the bar")',
                  'i18n.tr("Adds a fourth button to Back, Home and Apps.")',
                  '\n                visible: packSettings.mode === "bar"')
    out += """
            ListItem.Standard {
                height: units.gu(2)
                showDivider: true
            }

            SettingsItemTitle {
                text: i18n.tr("Three-finger gestures")
            }
"""
    out += switch("packGestures", "gestures", 'i18n.tr("Swipe with three fingers")',
                  'i18n.tr("Left or right switches between open apps, up opens the app switcher and down closes it. One and two fingers stay with the app.")')
    out += switch("packSwipeScreenshot", "swipeScreenshot", 'i18n.tr("Three fingers down for a screenshot")',
                  'i18n.tr("Swipe down with three fingers in an app to take a screenshot.")',
                  "\n                enabled: packSettings.gestures")
    out += """
            ListItem.Standard {
                height: units.gu(2)
                showDivider: true
            }

            SettingsItemTitle {
                text: i18n.tr("Lock screen")
            }
"""
    out += switch("packLockButtons", "lockButtons", 'i18n.tr("Camera and flashlight")',
                  'i18n.tr("Press and hold the bottom corners of the lock screen: the camera on the left (it opens once you unlock), the flashlight on the right.")')
    if dt2w:
        out += """
            ListItem.Standard {
                height: units.gu(2)
                showDivider: true
            }
"""
        out += switch("packDoubleTapWake", "doubleTapWake", 'i18n.tr("Double tap to wake")',
                      'i18n.tr("Double-tap the screen to wake the phone while it sleeps.")')
    return out


def main(args):
    dt2w = "--dt2w" in args
    args = [a for a in args if a != "--dt2w"]
    stock, out = args[:2]
    text = open(stock, "rb").read().decode()
    if "GesturePackLabs" in text:
        sys.exit("already patched")
    if text.count(IMPORT_AFTER) != 1 or text.count(ANCHOR) != 1:
        sys.exit("the Gestures page doesn't look like the one this was made for")
    text = text.replace(IMPORT_AFTER, IMPORT_AFTER + IMPORT)
    text = text.replace(ANCHOR, ANCHOR + section(dt2w))
    with open(out, "w", newline="\n") as f:
        f.write(text)
    print(f"wrote {out}")


if __name__ == "__main__":
    main(sys.argv[1:])
