import QtQuick
import "root:/config"

Item {
    id: root

    property real value: 0
    property real maximum: 1.0
    property color fillColor: Theme.accent
    property bool animated: true

    signal moved(real newValue)

    readonly property real ratio: root.maximum > 0 ? Math.min(Math.max(root.value / root.maximum, 0), 1) : 0

    implicitHeight: 18
    implicitWidth: 120

    function applyPosition(positionX: real): void {
        const clamped = Math.min(Math.max(positionX / root.width, 0), 1);
        root.moved(clamped * root.maximum);
    }

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        height: 4
        radius: Theme.pill(4)
        color: Theme.fillTrack

        Rectangle {
            id: fill

            anchors.left: parent.left
            anchors.top: parent.top

            width: parent.width * root.ratio
            height: parent.height
            radius: parent.radius
            color: root.fillColor

            Behavior on width {
                enabled: root.animated && !dragArea.pressed
                NumberAnimation {
                    duration: Theme.durationFast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }
    }

    Rectangle {
        id: handle

        width: 12
        height: 12
        radius: Theme.pill(12)
        color: Theme.textPrimary

        x: Math.min(Math.max(fill.width - width / 2, 0), root.width - width)
        anchors.verticalCenter: parent.verticalCenter

        Behavior on x {
            enabled: root.animated && !dragArea.pressed
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
        }
    }

    MouseArea {
        id: dragArea

        anchors.fill: parent

        onPressed: event => root.applyPosition(event.x)
        onPositionChanged: event => {
            if (dragArea.pressed)
                root.applyPosition(event.x);
        }
    }
}
