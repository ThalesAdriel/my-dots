import QtQuick
import "root:/config"

Rectangle {
    id: root

    property bool active: true

    radius: Theme.radius
    color: Theme.skeletonFill
    visible: active

    SequentialAnimation on opacity {
        running: root.active && root.visible
        loops: Animation.Infinite
        alwaysRunToEnd: false
        NumberAnimation {
            from: 1.0
            to: 0.4
            duration: 850
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: 0.4
            to: 1.0
            duration: 850
            easing.type: Easing.InOutSine
        }
    }
}
