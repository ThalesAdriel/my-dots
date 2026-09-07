import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

// What "Identify" puts on each screen: the number the arrangement canvas gives
// it, and the connector it belongs to. Over everything, reserving nothing, and
// with an empty input mask so it cannot take a click from whatever is under it.
PanelWindow {
    id: root

    required property var modelData

    readonly property int number: Displays.indexOf(modelData.name) + 1

    WlrLayershell.namespace: Theme.panelLayerNamespace
    WlrLayershell.layer: WlrLayer.Overlay

    screen: modelData

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: 0
    color: "transparent"
    visible: Displays.identifying && root.number > 0

    mask: Region {}

    Card {
        anchors.centerIn: parent

        width: 200
        height: 200

        opacity: Displays.identifying ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationBase
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -12

            text: String(root.number)
            color: Theme.textPrimary
            font.family: Theme.monoFamily
            font.pixelSize: 96
            font.weight: Font.Bold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26

            textFormat: Text.PlainText
            text: root.modelData.name
            color: Theme.textSecondary
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSize
        }
    }
}
