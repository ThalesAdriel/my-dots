import QtQuick

// Scrolls a Flickable straight from the wheel, with no momentum. A Flickable left to the wheel itself keeps gliding for a moment, and a click while it glides only stops it, so picking something just after scrolling took two clicks, or landed on whatever had slid under the pointer. At either end the wheel goes through to whatever scrolls around it. Put it under the Flickable, which is left non-interactive.
MouseArea {
    id: root

    property Flickable target
    property real step: 60

    acceptedButtons: Qt.NoButton

    onWheel: wheel => {
        const flickable = root.target;
        const delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * root.step;
        const top = flickable.originY;
        const bottom = flickable.originY + Math.max(flickable.contentHeight - flickable.height, 0);
        const next = Math.min(Math.max(flickable.contentY - delta, top), bottom);
        if (next === flickable.contentY) {
            wheel.accepted = false;
            return;
        }
        flickable.contentY = next;
    }
}
