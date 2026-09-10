import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

BarButton {
    id: root

    property bool inhibiting: true

    onPrimaryClicked: root.inhibiting = !root.inhibiting

    overlayContent: Loader {
        id: inhibitorLoader
        source: "root:/modules/WaylandIdleInhibitor.qml"
    }

    Binding {
        target: inhibitorLoader.item
        property: "window"
        value: root.QsWindow.window
        when: inhibitorLoader.status === Loader.Ready
    }

    Binding {
        target: inhibitorLoader.item
        property: "enabled"
        value: root.inhibiting
        when: inhibitorLoader.status === Loader.Ready
    }

    IconStack {

        IconText {
            anchors.centerIn: parent
            text: Glyphs.idleBlocked
            color: Theme.textPrimary
            opacity: root.inhibiting ? 1 : 0
            scale: root.inhibiting ? 1 : 0.7

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }

        IconText {
            anchors.centerIn: parent
            text: Glyphs.idleAllowed
            color: Theme.textPrimary
            opacity: root.inhibiting ? 0 : 1
            scale: root.inhibiting ? 0.7 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }
    }

    BarTooltip {
        anchorItem: root
        shown: root.containsMouse
        text: root.inhibiting ? "Idle inhibited" : "Idle allowed"
    }
}
