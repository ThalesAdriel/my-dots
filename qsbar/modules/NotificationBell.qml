import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

BarButton {
    id: root

    highlighted: controlCenter.shown

    onPrimaryClicked: controlCenter.toggle()
    onSecondaryClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb

    IconStack {

        Text {
            anchors.centerIn: parent
            height: Theme.barHeight
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter

            text: Notifications.doNotDisturb ? Glyphs.bellOffNerd : Glyphs.bellNerd
            color: Notifications.doNotDisturb ? Theme.textMuted : Theme.textPrimary
            font.family: Theme.nerdFamily
            font.pixelSize: Theme.iconSize + 2

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: -3
            anchors.top: parent.top
            anchors.topMargin: Math.max((Theme.barHeight - Theme.iconSize) / 2 - 4, 1)

            implicitWidth: Math.max(badgeLabel.implicitWidth + 5, 12)
            implicitHeight: 12
            width: implicitWidth
            height: implicitHeight
            radius: Theme.pill(12)

            color: Notifications.doNotDisturb ? Theme.textMuted : Theme.accent

            opacity: Notifications.count > 0 ? 1 : 0
            scale: Notifications.count > 0 ? 1 : 0.4

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durationSlow
                    easing.type: Easing.OutBack
                }
            }

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: Notifications.count > 9 ? "9+" : String(Notifications.count)
                color: Theme.textPrimary
                font.family: Theme.monoFamily
                font.pixelSize: 9
                font.weight: Font.Bold
            }
        }
    }

    ControlCenter {
        id: controlCenter
        anchorItem: root
    }

    BarTooltip {
        anchorItem: root
        shown: root.containsMouse && !controlCenter.shown
        text: {
            if (Notifications.doNotDisturb)
                return "Do not disturb";
            if (Notifications.count === 1)
                return "1 notification";
            return Notifications.count + " notifications";
        }
    }
}
