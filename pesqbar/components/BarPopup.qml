import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/config"

PopupWindow {
    id: root

    default property alias popupContent: contentHolder.data

    required property Item anchorItem
    property bool alignRight: false
    property int gap: 0
    property bool shown: false
    property bool dismissing: false
    property bool rendered: false

    // Room on either side of the panel for the fillets that weld it to the bar.
    // The window grows outwards, so the panel itself stays where it was.
    readonly property int cornerSize: Settings.outerCorners ? Settings.outerCornerRadius : 0

    function toggle(): void {
        if (root.dismissing)
            return;
        root.shown = !root.shown;
    }

    anchor.item: anchorItem
    anchor.rect.y: anchorItem ? anchorItem.height + root.gap : 0
    anchor.rect.x: {
        if (!anchorItem)
            return 0;
        return root.alignRight ? anchorItem.width - root.implicitWidth : (anchorItem.width - root.implicitWidth) / 2;
    }

    implicitWidth: contentHolder.implicitWidth + root.cornerSize * 2
    implicitHeight: contentHolder.implicitHeight

    color: "transparent"
    visible: root.rendered

    data: [
        HyprlandFocusGrab {
            windows: [root]
            active: root.shown
            onCleared: {
                root.shown = false;
                root.dismissing = true;
                dismissGuard.restart();
            }
        },

        Timer {
            id: dismissGuard
            interval: 200
            onTriggered: root.dismissing = false
        },

        Binding {
            target: root
            property: "rendered"
            value: true
            when: root.shown
            restoreMode: Binding.RestoreNone
        },

        Timer {
            interval: Theme.durationBase + 60
            running: !root.shown && root.rendered
            onTriggered: root.rendered = false
        },

        Item {
            id: clipper

            anchors.fill: parent
            clip: true

            Rectangle {
                id: surface

                // Welded to the bar, the panel's top corners are pushed up out
                // of the clip so they come out square against it.
                readonly property int lift: root.cornerSize > 0 ? Theme.cardRadius : 0

                x: root.cornerSize
                width: parent.width - root.cornerSize * 2
                height: parent.height + surface.lift
                y: root.shown ? -surface.lift : -height

                color: Theme.popupBackground
                border.color: Theme.popupBorder
                border.width: Theme.panelBorderWidth
                radius: Theme.cardRadius

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.durationBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                }

                Item {
                    id: contentHolder

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: surface.lift
                    anchors.bottom: parent.bottom

                    implicitWidth: childrenRect.width
                    implicitHeight: childrenRect.height
                }
            }

            OuterCorner {
                x: 0
                y: surface.y + surface.lift

                size: root.cornerSize
                fillColor: Theme.popupBackground
                centreRight: true
            }

            OuterCorner {
                x: clipper.width - root.cornerSize
                y: surface.y + surface.lift

                size: root.cornerSize
                fillColor: Theme.popupBackground
                centreRight: false
            }
        }
    ]
}
