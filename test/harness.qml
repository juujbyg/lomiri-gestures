import QtQuick 2.15
import Lomiri.Components 1.3
import "lomiri/Components"

Item {
    // Stands in for an app under the shell's gesture area.
    MultiPointTouchArea {
        objectName: "app"
        anchors.fill: parent
        property int maxPressed: 0
        property real moved: 0
        onPressed: maxPressed = Math.max(maxPressed, touchPoints.length)
        onUpdated: moved = Math.max(moved, Math.abs(touchPoints[0].x - touchPoints[0].startX))
    }
    MultiFingerGestures {
        objectName: "gestures"
        anchors.fill: parent
        hintFor: function(gesture, fingers) { return gesture === "" ? "" : gesture + "/" + fingers; }
    }
}
