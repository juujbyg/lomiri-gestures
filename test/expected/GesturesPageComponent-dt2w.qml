/*
 * Copyright (C) 2022 UBports Foundation
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.12
import SystemSettings 1.0
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3 as ListItem
import SystemSettings.ListItems 1.0 as SettingsListItems
import Lomiri.Settings.Menus 0.1 as Menus
import Lomiri.Settings.Components 0.1 as LSC
import Lomiri.SystemSettings.Gestures 1.0
import GSettings 1.0
import Qt.labs.settings 1.1 as GesturePackLabs

ItemPage {
    id: root
    title: i18n.tr("Gestures")
    flickable: gesturesFlickable

    GSettings {
        id: shellGsetting
        schema.id: "com.lomiri.Shell"
    }

    GSettings {
        id: gsettings
        schema.id: "com.lomiri.touch.system"
    }

    Flickable {
        id: gesturesFlickable
        anchors.fill: parent
        contentHeight: contentItem.childrenRect.height
        boundsBehavior: (contentHeight > root.height) ?
                            Flickable.DragAndOvershootBounds :
                            Flickable.StopAtBounds
        /* Workaround https://bugreports.qt-project.org/browse/QTBUG-31905 */
        flickableDirection: Flickable.VerticalFlick

        Column {
            anchors.left: parent.left
            anchors.right: parent.right

            SettingsListItems.Standard {
                id: doubleTapToWake
                text: i18n.tr("Tap to wake")
                visible: DbusHelper.isDT2WSupported
                Switch {
                    id: doubleTapToWakeSwitch
                    objectName: "doubleTapToWake"
                    property bool serverChecked: gsettings.doubleTapToWake
                    onServerCheckedChanged: checked = serverChecked
                    Component.onCompleted: checked = serverChecked
                    onTriggered: gsettings.doubleTapToWake = checked
                }
                showDivider: false
            }

            Label {
                anchors {
                    left:parent.left
                    right:parent.right
                    leftMargin: units.gu(2)
                    rightMargin: units.gu(2)
                }
                text: i18n.tr("Double-tap anywhere on the screen to wake device.")
                wrapMode: Text.WordWrap
                visible: doubleTapToWake.visible
            }

            ListItem.Standard {
                id: divider
                height: divider.height + units.gu(2)
                visible: doubleTapToWake.visible
                showDivider: true
            }

            // edge drag with setting for changing the corresponding gsetting
            SettingsItemTitle {
                text: i18n.tr("Edge drag areas width:")
            }
            SettingsListItems.Standard {
                Column {
                    spacing: units.gu(1)
                    bottomPadding: units.gu(1)
                    anchors {
                        left: parent.left
                        leftMargin: units.gu(2)
                        right: parent.right
                        rightMargin: units.gu(2)
                    }

                    Label {
                        text: i18n.tr("Current value: %1").arg(shellGsetting.edgeDragWidth)
                    }
                    // slider row with min and max labels
                    Row {
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        Label {
                            id: minValueLabel
                            width: units.gu(2)
                            text: dragSensitivity.minimumValue
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Menus.SliderMenu {
                            id: dragSensitivity
                            width: parent.width - (minValueLabel.width + maxValueLabel.width)
                            function formatValue(v) { return v }
                            minimumValue: 1
                            maximumValue: 5
                            value: shellGsetting.edgeDragWidth
                            live: true

                            property real sliderValue: Math.round(dragSensitivity.value)

                            LSC.ServerPropertySynchroniser {
                                userTarget: dragSensitivity
                                userProperty: "value"
                                serverTarget: dragSensitivity
                                serverProperty: "sliderValue"

                                onSyncTriggered: shellGsetting.edgeDragWidth = Math.round(value);
                            }
                            // apply the current value once the component has finished initial loading
                            Component.onCompleted: value = shellGsetting.edgeDragWidth
                        }

                        Label {
                            id: maxValueLabel
                            width: units.gu(2)
                            text: dragSensitivity.maximumValue
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Label {
                        text: i18n.tr("With a higher value, the swipe area at the edges to trigger an action is wider. The default value is 2.")
                        anchors.left:parent.left
                        anchors.right:parent.right
                        wrapMode: Text.WordWrap
                    }
                }
            }

            SettingsListItems.Standard {
                id: screenshotEditor
                text: i18n.tr("Screenshot editor")
                Switch {
                    id: screenshotEditorSwitch
                    objectName: "screenshotEditor"
                    property bool serverChecked: shellGsetting.enableScreenshotEditor
                    onServerCheckedChanged: checked = serverChecked
                    Component.onCompleted: checked = serverChecked
                    onTriggered: shellGsetting.enableScreenshotEditor = checked
                }
                showDivider: false
            }

            Label {
                anchors {
                    left:parent.left
                    right:parent.right
                    leftMargin: units.gu(2)
                    rightMargin: units.gu(2)
                }
                text: i18n.tr("Allow editing screenshots when pressing Vol+ & Vol-.")
                wrapMode: Text.WordWrap
            }

            // Gesture Pack (github.com/juujbyg/lomiri-gestures)
            GesturePackLabs.Settings {
                id: packSettings
                fileName: "/home/phablet/.config/lomiri-gesture-pack/settings.conf"
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

            SettingsListItems.Standard {
                id: packBarScreenshotRow
                text: i18n.tr("Screenshot button on the bar")
                visible: packSettings.mode === "bar"
                Switch {
                    objectName: "packBarScreenshot"
                    property bool serverChecked: packSettings.barScreenshot
                    onServerCheckedChanged: checked = serverChecked
                    Component.onCompleted: checked = serverChecked
                    onTriggered: packSettings.barScreenshot = checked
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
                text: i18n.tr("Adds a fourth button to Back, Home and Apps.")
                wrapMode: Text.WordWrap
                visible: packBarScreenshotRow.visible
                opacity: packBarScreenshotRow.enabled ? 1 : 0.5
            }

            ListItem.Standard {
                height: units.gu(2)
                showDivider: true
            }

            SettingsItemTitle {
                text: i18n.tr("Three-finger gestures")
            }

            SettingsListItems.Standard {
                id: packGesturesRow
                text: i18n.tr("Swipe with three fingers")
                Switch {
                    objectName: "packGestures"
                    property bool serverChecked: packSettings.gestures
                    onServerCheckedChanged: checked = serverChecked
                    Component.onCompleted: checked = serverChecked
                    onTriggered: packSettings.gestures = checked
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
                text: i18n.tr("Left or right switches between open apps, up opens the app switcher and down closes it. One and two fingers stay with the app.")
                wrapMode: Text.WordWrap
                visible: packGesturesRow.visible
                opacity: packGesturesRow.enabled ? 1 : 0.5
            }

            SettingsListItems.Standard {
                id: packSwipeScreenshotRow
                text: i18n.tr("Three fingers down for a screenshot")
                enabled: packSettings.gestures
                Switch {
                    objectName: "packSwipeScreenshot"
                    property bool serverChecked: packSettings.swipeScreenshot
                    onServerCheckedChanged: checked = serverChecked
                    Component.onCompleted: checked = serverChecked
                    onTriggered: packSettings.swipeScreenshot = checked
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
                text: i18n.tr("Swipe down with three fingers in an app to take a screenshot.")
                wrapMode: Text.WordWrap
                visible: packSwipeScreenshotRow.visible
                opacity: packSwipeScreenshotRow.enabled ? 1 : 0.5
            }

            ListItem.Standard {
                height: units.gu(2)
                showDivider: true
            }

            SettingsItemTitle {
                text: i18n.tr("Lock screen")
            }

            SettingsListItems.Standard {
                id: packLockButtonsRow
                text: i18n.tr("Camera and flashlight")
                Switch {
                    objectName: "packLockButtons"
                    property bool serverChecked: packSettings.lockButtons
                    onServerCheckedChanged: checked = serverChecked
                    Component.onCompleted: checked = serverChecked
                    onTriggered: packSettings.lockButtons = checked
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
                text: i18n.tr("Press and hold the bottom corners of the lock screen: the camera on the left (it opens once you unlock), the flashlight on the right.")
                wrapMode: Text.WordWrap
                visible: packLockButtonsRow.visible
                opacity: packLockButtonsRow.enabled ? 1 : 0.5
            }

            ListItem.Standard {
                height: units.gu(2)
                showDivider: true
            }

            SettingsListItems.Standard {
                id: packDoubleTapWakeRow
                text: i18n.tr("Double tap to wake")
                Switch {
                    objectName: "packDoubleTapWake"
                    property bool serverChecked: packSettings.doubleTapWake
                    onServerCheckedChanged: checked = serverChecked
                    Component.onCompleted: checked = serverChecked
                    onTriggered: packSettings.doubleTapWake = checked
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
                text: i18n.tr("Double-tap the screen to wake the phone while it sleeps.")
                wrapMode: Text.WordWrap
                visible: packDoubleTapWakeRow.visible
                opacity: packDoubleTapWakeRow.enabled ? 1 : 0.5
            }
        }
    }
}
