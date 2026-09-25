import QtQuick
import "root:/config"

// The outline a control draws round itself while it has the keyboard. Only Tab ever gives these controls focus, since their MouseAreas do not take it, so a click never leaves a ring behind.
Rectangle {
    property Item target: parent

    anchors.fill: target
    anchors.margins: -3

    radius: Theme.radius > 0 ? Theme.radius + 3 : 0
    color: "transparent"
    border.width: 1
    border.color: Theme.accent
    visible: target !== null && target.activeFocus
}
