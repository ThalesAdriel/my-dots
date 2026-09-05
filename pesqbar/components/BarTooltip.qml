import QtQuick
import Quickshell
import "root:/config"

PopupWindow {
    id: root

    required property Item anchorItem
    property string text: ""
    property bool shown: false
    property int gap: 6

    anchor.item: anchorItem
    anchor.rect.y: anchorItem ? anchorItem.height + root.gap : 0
    anchor.rect.x: anchorItem ? (anchorItem.width - root.implicitWidth) / 2 : 0

    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12

    color: "transparent"
    visible: (root.shown || surface.opacity > 0.01) && root.text !== ""

    Rectangle {
        id: surface
        anchors.fill: parent

        color: Theme.popupBackground
        border.color: Theme.popupBorder
        border.width: Theme.panelBorderWidth
        radius: Theme.radius

        opacity: root.shown ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
