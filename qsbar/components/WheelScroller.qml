import QtQuick

// Scrolls a Flickable straight from the wheel, with no momentum.
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
