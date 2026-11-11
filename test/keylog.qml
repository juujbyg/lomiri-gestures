// Shows a window and logs every key it receives, and whether a Back shortcut fires.
import QtQuick 2.12
import QtQuick.Window 2.12

Window {
    visible: true
    color: "#1f2430"
    Text { anchors.centerIn: parent; color: "white"; font.pixelSize: 40; text: "key test" }
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: console.log("KEY pressed key=" + event.key + " (Back=" + Qt.Key_Back + ", Esc=" + Qt.Key_Escape + ") native=" + event.nativeScanCode + " text='" + event.text + "'")
    }
    Shortcut { sequence: StandardKey.Back; onActivated: console.log("SHORTCUT StandardKey.Back fired") }
    Timer { interval: 25000; running: true; onTriggered: Qt.quit() }
}
