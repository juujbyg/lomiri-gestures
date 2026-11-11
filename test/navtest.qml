// Loads the plugin outside the shell, waits for the device, presses Back once.
import QtQuick 2.12
import LomiriNav 1.0 as Nav

Item {
    Component.onCompleted: console.log("NAVTEST loaded: enabled=" + Nav.NavKeys.enabled + " side=" + Nav.NavKeys.side
                                       + " position=" + Nav.NavKeys.position + " ready=" + Nav.NavKeys.ready)
    Connections {
        target: Nav.NavKeys
        function onReadyChanged() {
            console.log("NAVTEST ready=" + Nav.NavKeys.ready)
            hold.start()
        }
    }
    // Keep the device alive long enough for the checks in the test script.
    Timer { id: hold; interval: 2500; onTriggered: { console.log("NAVTEST back sent=" + Nav.NavKeys.back()); quit.start() } }
    Timer { id: quit; interval: 800; onTriggered: Qt.quit() }
}
