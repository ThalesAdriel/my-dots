import QtQuick
import "root:/config"

// The outline a control draws round itself while it has the keyboard.
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
