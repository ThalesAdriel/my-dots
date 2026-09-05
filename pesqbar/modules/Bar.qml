import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"

PanelWindow {
    id: root

    WlrLayershell.namespace: Theme.barLayerNamespace

    required property var modelData

    // The fillets hang below the bar, so the window is taller than the bar
    // while still only reserving the bar's own height from the compositor.
    readonly property int cornerSize: Settings.outerCorners ? Settings.outerCornerRadius : 0

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight + root.cornerSize
    exclusiveZone: Theme.barHeight
    color: "transparent"

    // Only the bar itself takes input. The fillets sit over the desktop.
    mask: Region {
        item: barArea
    }

    Item {
        id: barArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: Theme.barHeight

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right

            y: -Settings.barRadius
            height: parent.height + Settings.barRadius
            radius: Settings.barRadius
            color: Theme.barBackground
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            visible: Settings.showTopBorder
            color: Theme.barBorder
        }

        Row {
            id: leftGroup

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6
            spacing: Theme.moduleSpacing
            opacity: 0

            Workspaces {
            }

            WindowTitle {
            }
        }

        Clock {
            id: centerGroup

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6
            opacity: 0
        }

        Row {
            id: rightGroup

            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6
            spacing: Theme.moduleSpacing
            opacity: 0

            TrayDrawer {
            }

            IdleToggle {
            }

            Volume {
            }

            NotificationBell {
            }

            DateField {
            }
        }
    }

    OuterCorner {
        anchors.left: parent.left
        anchors.top: barArea.bottom

        size: root.cornerSize
        fillColor: Theme.barBackground
        centreRight: false
    }

    OuterCorner {
        anchors.right: parent.right
        anchors.top: barArea.bottom

        size: root.cornerSize
        fillColor: Theme.barBackground
        centreRight: true
    }

    component EntranceAnimation: SequentialAnimation {
        required property Item item
        required property int delay

        running: true

        PauseAnimation {
            duration: delay
        }

        ParallelAnimation {
            NumberAnimation {
                target: item
                property: "opacity"
                to: 1
                duration: Theme.durationSlow
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
            NumberAnimation {
                target: item
                property: "anchors.verticalCenterOffset"
                to: 0
                duration: Theme.durationSlow
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
        }
    }

    EntranceAnimation {
        item: leftGroup
        delay: 0
    }

    EntranceAnimation {
        item: centerGroup
        delay: 90
    }

    EntranceAnimation {
        item: rightGroup
        delay: 180
    }
}
