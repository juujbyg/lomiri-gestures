/*
 * Gesture Pack: camera (bottom left) and flashlight (bottom right) on the lock
 * screen's cover page. Press and hold, so they don't go off in a pocket; a
 * tap only says so.
 *
 * Loaded by a Loader inside the cover page in Greeter/GreeterView.qml, so it
 * slides away with the cover. The flashlight is the same switch as in the
 * battery indicator. The camera asks for the passcode (or fingerprint) first
 * and opens once the phone is unlocked: a camera over the lock screen would
 * show its gallery of every photo to whoever holds the phone.
 */
import QtQuick 2.15
import Lomiri.Components 1.3
import QMenuModel 1.0
import GesturePack 1.0

Item {
    id: root

    readonly property string cameraApp: "camera.ubports_camera"
    // The shell's own function for opening an app (it starts the unlock).
    readonly property var shellItem: typeof shell !== "undefined" ? shell : null

    readonly property real size: units.gu(6.5)
    readonly property real margin: units.gu(3.5)

    visible: GesturePack.lockButtons

    QDBusActionGroup {
        id: power
        busType: DBus.SessionBus
        busName: "org.ayatana.indicator.power"
        objectPath: "/org/ayatana/indicator/power"
        property variant flashlight: action("flashlight")
        Component.onCompleted: start()
    }
    readonly property bool hasTorch: power.flashlight && power.flashlight.valid
    readonly property bool torchOn: hasTorch && power.flashlight.state === true

    function openCamera() {
        if (!shellItem) return
        shellItem.activateApplication(cameraApp)
    }

    function toggleTorch() {
        // The action takes the wanted state (a boolean), not a plain toggle.
        if (hasTorch) power.flashlight.activate(!torchOn)
    }

    component CornerButton: Item {
        id: button
        property string iconName
        property bool lit: false
        property string hint
        signal held()
        width: root.size
        height: root.size
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.margin

        MouseArea {
            id: area
            anchors.fill: parent
            // The cover page's swipe handler watches every touch; don't let it take this one.
            preventStealing: true
            pressAndHoldInterval: 400
            property bool fired: false
            onPressed: fired = false
            onPressAndHold: {
                fired = true
                Haptics.play()
                button.held()
            }
            onReleased: {
                if (fired) return
                hintLabel.text = button.hint
                hintTimer.restart()
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: button.lit ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(0.1, 0.1, 0.12, area.pressed ? 0.75 : 0.45)
            border.color: Qt.rgba(1, 1, 1, 0.35)
            border.width: units.dp(1)
            scale: area.pressed ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Icon {
            anchors.centerIn: parent
            width: root.size * 0.45
            height: width
            name: button.iconName
            color: button.lit ? "black" : "white"
        }
    }

    CornerButton {
        objectName: "gesturePackCamera"
        anchors.left: parent.left
        anchors.leftMargin: root.margin
        iconName: "camera-symbolic"
        hint: i18n.tr("Press and hold to open the camera")
        visible: root.shellItem !== null
        onHeld: root.openCamera()
    }

    CornerButton {
        objectName: "gesturePackFlashlight"
        anchors.right: parent.right
        anchors.rightMargin: root.margin
        iconName: root.torchOn ? "torch-on" : "torch-off"
        lit: root.torchOn
        hint: root.torchOn ? i18n.tr("Press and hold to turn off the flashlight")
                           : i18n.tr("Press and hold to turn on the flashlight")
        visible: root.hasTorch
        onHeld: root.toggleTorch()
    }

    Label {
        id: hintLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.margin + root.size + units.gu(1.5)
        color: "white"
        opacity: hintTimer.running ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
    Timer { id: hintTimer; interval: 1800 }
}
