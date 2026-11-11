"""Add a "Navigation" choice (Off, Back button, Back/Home/Apps) to System Settings > Gestures.

    python make-settings.py <stock PageComponent.qml> <out PageComponent.qml>

The choice edits "mode" in ~/.config/lomiri-nav/settings.conf, the file the
shell's LomiriNav plugin watches, so the change shows at once.
"""
import sys

SETTINGS_FILE = "/home/phablet/.config/lomiri-nav/settings.conf"

IMPORT_AFTER = "import GSettings 1.0\n"
IMPORT = "import Qt.labs.settings 1.1 as LomiriNavLabs\n"

ANCHOR = """                text: i18n.tr("Allow editing screenshots when pressing Vol+ & Vol-.")
                wrapMode: Text.WordWrap
            }
"""

SECTION = """
            // LomiriNav: floating navigation (goals/lomiri-nav). One style at a time.
            LomiriNavLabs.Settings {
                id: navSettings
                fileName: "%s"
                property string mode: "button"
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
                selectedIndex: Math.max(0, modes.indexOf(navSettings.mode))
                onDelegateClicked: navSettings.mode = modes[index]
            }

            Label {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: units.gu(2)
                    rightMargin: units.gu(2)
                    topMargin: units.gu(1)
                }
                text: i18n.tr("Floating navigation over apps, in thumb reach. Drag it to move it; press and hold it to switch style or hide it.")
                wrapMode: Text.WordWrap
            }
""" % SETTINGS_FILE


def main(stock, out):
    data = open(stock, "rb").read()
    text = data.decode()
    if text.count(IMPORT_AFTER) != 1 or text.count(ANCHOR) != 1:
        sys.exit("the Gestures page doesn't look like the one this was made for")
    text = text.replace(IMPORT_AFTER, IMPORT_AFTER + IMPORT)
    text = text.replace(ANCHOR, ANCHOR + SECTION)
    with open(out, "w", newline="\n") as f:
        f.write(text)
    print(f"wrote {out}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
