// Loads the plugin outside the shell, waits for the device, presses Back once.
import QtQuick 2.12
import GesturePack 1.0

Item {
    Component.onCompleted: console.log("NAVTEST loaded: mode=" + GesturePack.mode + " side=" + GesturePack.side
                                       + " gestures=" + GesturePack.gestures + " swipeScreenshot=" + GesturePack.swipeScreenshot
                                       + " barScreenshot=" + GesturePack.barScreenshot + " ready=" + GesturePack.ready)
    Connections {
        target: GesturePack
        function onReadyChanged() {
            console.log("NAVTEST ready=" + GesturePack.ready)
            hold.start()
        }
    }
    // Keep the device alive long enough for the checks in the test script.
    Timer { id: hold; interval: 2500; onTriggered: { console.log("NAVTEST back sent=" + GesturePack.back()); quit.start() } }
    Timer { id: quit; interval: 800; onTriggered: Qt.quit() }
}
