/*
 * Gesture Pack: floating navigation for Lomiri, in thumb reach. One of two
 * styles, chosen in System Settings > Gestures (or from its own press-and-hold menu):
 *   "button": a round Back button
 *   "bar":    a pill with Back, Home and Apps, and optionally Screenshot
 *
 * Tap: Back (Alt+Left, the StandardKey.Back shortcut), Home (the app drawer),
 *      Apps (Super+W, the spread) or Screenshot.
 * Drag: move it; it snaps to a side (the bar also to the middle) and remembers the height.
 * Press and hold: take a screenshot, switch style, or hide it.
 *
 * Loaded by Shell.qml's gesturePack Loader, which provides navAllowed, hiding,
 * topInset, keyboardHeight, goHome() and screenshot(). The shell reads
 * gesturesOn and swipeScreenshotOn from here, so it never imports the plugin.
 */
import QtQuick 2.15
import Lomiri.Components 1.3
import GesturePack 1.0

Item {
    id: root
    readonly property Item host: parent

    readonly property string mode: GesturePack.mode
    readonly property bool isBar: mode === "bar"
    readonly property bool shown: host.navAllowed && GesturePack.ready && mode !== "off"
    readonly property bool gesturesOn: GesturePack.gestures
    readonly property bool swipeScreenshotOn: GesturePack.swipeScreenshot

    readonly property real margin: units.gu(1.5)
    readonly property real cell: units.gu(6)
    readonly property var actions: !isBar ? [ { icon: "back", act: "back" } ]
        : [ { icon: "back", act: "back" }, { icon: "home", act: "home" }, { icon: "view-grid-symbolic", act: "apps" } ]
          .concat(GesturePack.barScreenshot ? [ { icon: "camera-symbolic", act: "screenshot" } ] : [])
    readonly property real navWidth: isBar ? cell * actions.length + units.gu(2) : cell
    readonly property real lowest: height - host.keyboardHeight - margin - cell
    readonly property real highest: host.topInset + units.gu(10)
    readonly property real travel: Math.max(0, lowest - highest)
    // The round button has no middle place: it uses the right side then.
    readonly property string side: !isBar && GesturePack.side === "center" ? "right" : GesturePack.side

    function homeX() {
        if (side === "left") return margin
        if (side === "center") return (width - navWidth) / 2
        return width - navWidth - margin
    }
    function homeY() { return lowest - GesturePack.position * travel }

    function run(act) {
        Haptics.play()
        if (act === "back") GesturePack.back()
        else if (act === "home") host.goHome()
        else if (act === "apps") GesturePack.apps()
        else if (act === "screenshot") host.screenshot()
    }

    Rectangle {
        id: nav
        objectName: "navOverlayItem"
        width: root.navWidth
        height: root.cell
        radius: height / 2
        x: root.homeX()
        y: root.homeY()
        visible: opacity > 0 && !root.host.hiding     // hidden at once for screenshots
        opacity: root.shown ? 1 : 0
        color: Qt.rgba(0.1, 0.1, 0.12, area.pressed && !root.isBar ? 0.75 : 0.45)
        border.color: Qt.rgba(1, 1, 1, 0.35)
        border.width: units.dp(1)

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on width { NumberAnimation { duration: 150 } }
        Behavior on y { enabled: !area.drag.active; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on x { enabled: !area.drag.active; NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        Row {
            id: cells
            anchors.centerIn: parent
            Repeater {
                model: root.actions
                delegate: Item {
                    width: root.cell
                    height: root.cell
                    Rectangle {      // pressed highlight, bar only
                        anchors.centerIn: parent
                        width: parent.width * 0.85
                        height: width
                        radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.18)
                        visible: root.isBar && area.pressed && !area.drag.active && area.pressedIndex === index
                    }
                    Icon {
                        anchors.centerIn: parent
                        width: root.cell * 0.5
                        height: width
                        name: modelData.icon
                        color: "white"
                    }
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            enabled: root.shown
            drag.target: nav
            drag.minimumX: 0
            drag.maximumX: root.width - root.navWidth
            drag.minimumY: root.highest
            drag.maximumY: root.lowest
            drag.threshold: units.gu(1.5)

            property int pressedIndex: -1
            function indexAt(x) {
                var i = Math.floor((x - cells.x) / root.cell)
                return Math.max(0, Math.min(root.actions.length - 1, i))
            }
            onPressed: pressedIndex = indexAt(mouse.x)
            onClicked: root.run(root.actions[indexAt(mouse.x)].act)
            onPressAndHold: {
                if (drag.active) return
                Haptics.play()
                menu.visible = true
            }
            drag.onActiveChanged: {
                if (drag.active) return
                var mid = nav.x + root.navWidth / 2
                if (root.isBar && Math.abs(mid - root.width / 2) < root.width / 6) GesturePack.side = "center"
                else GesturePack.side = mid < root.width / 2 ? "left" : "right"
                GesturePack.position = root.travel > 0 ? (root.lowest - nav.y) / root.travel : 0
                // Dragging replaced the bindings; put them back.
                nav.x = Qt.binding(root.homeX)
                nav.y = Qt.binding(root.homeY)
            }
        }
    }

    // Press-and-hold menu.
    MouseArea {
        anchors.fill: parent
        visible: menu.visible
        onClicked: menu.visible = false
    }
    Rectangle {
        id: menu
        visible: false
        onVisibleChanged: if (visible && !root.shown) visible = false
        width: units.gu(28)
        height: column.height + units.gu(2)
        radius: units.gu(1)
        color: Qt.rgba(0.1, 0.1, 0.12, 0.92)
        x: Math.max(root.margin, Math.min(root.width - width - root.margin, nav.x + (nav.width - width) / 2))
        y: Math.max(root.host.topInset, nav.y - height - units.gu(1))

        Column {
            id: column
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: units.gu(1) }
            spacing: units.gu(0.5)
            Repeater {
                model: [
                    { text: i18n.tr("Take screenshot"), action: "screenshot" },
                    { text: root.isBar ? i18n.tr("Use a back button instead") : i18n.tr("Use Back, Home and Apps instead"),
                      action: root.isBar ? "button" : "bar" },
                    { text: i18n.tr("Hide navigation"), action: "off" },
                    { text: i18n.tr("Cancel"), action: "cancel" }
                ]
                delegate: AbstractButton {
                    width: column.width
                    height: units.gu(5)
                    onClicked: {
                        menu.visible = false
                        if (modelData.action === "screenshot") root.host.screenshot()
                        else if (modelData.action !== "cancel") GesturePack.mode = modelData.action
                    }
                    Label {
                        anchors { left: parent.left; leftMargin: units.gu(1); right: parent.right; verticalCenter: parent.verticalCenter }
                        text: modelData.text
                        color: "white"
                        elide: Text.ElideRight
                    }
                }
            }
            Label {
                x: units.gu(1)
                width: column.width - units.gu(2)
                wrapMode: Text.WordWrap
                textSize: Label.Small
                color: Qt.rgba(1, 1, 1, 0.6)
                text: i18n.tr("System Settings > Gestures > Navigation brings it back.")
            }
        }
    }
}
