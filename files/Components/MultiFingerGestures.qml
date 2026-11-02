/*
 * Copyright (C) 2026 juujbyg
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.15
import Lomiri.Components 1.3
import Lomiri.Gestures 0.1

/*
 Trackpad-style gestures made with three or four fingers anywhere on the
 screen. One or two fingers are never taken, so apps keep their own
 scrolling and pinch-to-zoom.

 While the fingers are down, a hint names what will happen on release, so
 a gesture can be cancelled by moving the fingers back. On release,
 triggered() is emitted with one of:
   "swipeLeft", "swipeRight", "swipeUp", "swipeDown",
   "pinchIn", "pinchOut", "tap"
 */
TouchGestureArea {
    id: root

    minimumTouchPoints: 3
    maximumTouchPoints: 4

    // Distance the fingers must travel together before a swipe counts.
    property real swipeThreshold: units.gu(7)
    // How much the fingers must close or open before a pinch counts.
    property real pinchInRatio: 0.7
    property real pinchOutRatio: 1.4

    // Text shown while a gesture is in progress, given its name and finger
    // count. Return "" when the gesture would do nothing.
    property var hintFor: function(gesture, fingers) { return ""; }

    readonly property string pendingGesture: d.gesture
    readonly property int fingers: d.fingers

    signal triggered(string gesture, int fingers)

    QtObject {
        id: d
        property bool tracking: false
        property int fingers: 0
        property int count: 0
        property real startX: 0
        property real startY: 0
        property real startSpread: 1
        property real dx: 0
        property real dy: 0
        property real ratio: 1
        property bool moved: false
        property string gesture: ""

        // Set once the gesture has fired, until every finger is up.
        property bool committed: false

        function commit() {
            var g = gesture;
            var f = fingers;
            reset();
            committed = true;
            if (g !== "") {
                root.triggered(g, f);
            }
        }

        function reset() {
            tracking = false;
            fingers = 0;
            count = 0;
            dx = 0;
            dy = 0;
            ratio = 1;
            moved = false;
            gesture = "";
        }

        function measure() {
            var n = root.touchPoints.length;
            if (n === 0) {
                return null;
            }
            var cx = 0, cy = 0;
            for (var i = 0; i < n; i++) {
                cx += root.touchPoints[i].x;
                cy += root.touchPoints[i].y;
            }
            cx /= n;
            cy /= n;
            var spread = 0;
            for (var j = 0; j < n; j++) {
                spread += Math.sqrt(Math.pow(root.touchPoints[j].x - cx, 2) +
                                    Math.pow(root.touchPoints[j].y - cy, 2));
            }
            return { n: n, x: cx, y: cy, spread: Math.max(spread / n, 1) };
        }

        function update() {
            var m = measure();
            if (!m) {
                return;
            }
            if (!tracking) {
                tracking = true;
                startX = m.x;
                startY = m.y;
                startSpread = m.spread;
            } else if (m.n !== count) {
                // A finger was added or lifted. Move the reference point so
                // the jump in the centre doesn't read as movement.
                startX = m.x - dx;
                startY = m.y - dy;
                startSpread = m.spread / ratio;
            }
            count = m.n;
            fingers = Math.max(fingers, m.n);
            dx = m.x - startX;
            dy = m.y - startY;
            ratio = m.spread / startSpread;

            var travel = Math.max(Math.abs(dx), Math.abs(dy));
            var pinch = Math.abs(m.spread - startSpread);
            if (travel > units.gu(2) || pinch > units.gu(2)) {
                moved = true;
            }

            if ((ratio < root.pinchInRatio || ratio > root.pinchOutRatio) && pinch > travel) {
                gesture = ratio < 1 ? "pinchIn" : "pinchOut";
            } else if (travel > root.swipeThreshold) {
                if (Math.abs(dx) > Math.abs(dy)) {
                    gesture = dx < 0 ? "swipeLeft" : "swipeRight";
                } else {
                    gesture = dy < 0 ? "swipeUp" : "swipeDown";
                }
            } else if (!moved) {
                gesture = "tap";
            } else {
                gesture = "";
            }
        }
    }

    onTouchPointsUpdated: {
        if (status === TouchGestureArea.Recognized && !d.committed) {
            d.update();
        }
    }

    onStatusChanged: {
        if (status === TouchGestureArea.Recognized) {
            if (d.committed) {
                return;
            }
            if (!d.tracking) {
                d.update();
            } else {
                // Still "Recognized", emitted again: fewer fingers than the
                // minimum are left on the glass. That is the end of the
                // gesture, so act now rather than when the last finger lifts.
                d.commit();
            }
        } else {
            if (status === TouchGestureArea.WaitingForTouch && d.tracking && !d.committed) {
                d.commit();
            }
            // Rejected means too many fingers; nothing happens.
            d.reset();
            d.committed = false;
        }
    }

    Rectangle {
        id: hint
        objectName: "multiFingerGestureHint"
        readonly property string text: d.tracking && d.gesture !== "tap"
                                       ? root.hintFor(d.gesture, d.fingers) : ""
        anchors.centerIn: parent
        width: hintLabel.implicitWidth + units.gu(4)
        height: hintLabel.implicitHeight + units.gu(2)
        radius: height / 2
        color: "#cc111111"
        opacity: text !== "" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { LomiriNumberAnimation { duration: LomiriAnimation.SnapDuration } }

        Label {
            id: hintLabel
            anchors.centerIn: parent
            text: hint.text
            color: "white"
            textSize: Label.Large
        }
    }
}
