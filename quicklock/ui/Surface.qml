import QtQuick
import qs.config
import qs.services

Item {
    id: root

    focus: true

    Keys.onPressed: event => Auth.handleKey(event)

    Component.onCompleted: root.forceActiveFocus()

    Backdrop {
        anchors.fill: parent
    }

    HoverHandler {
        onPointChanged: Auth.activity()
    }

    Item {
        id: content

        anchors.fill: parent

        opacity: Auth.unlocking ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animNormal
                easing.type: Easing.OutQuad
            }
        }

        StatusLine {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Config.statusMarginX
            anchors.topMargin: Config.statusMarginY
        }

        CaffeineToggle {
            id: caffeine

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Config.statusMarginX - caffeine.pad
            anchors.topMargin: Config.statusMarginY - caffeine.pad
        }

        TextLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -Config.clockOffset

            text: Clock.time
            font.family: Config.fontFamilyClock
            font.weight: Font.DemiBold
            font.pixelSize: Config.clockSize
        }

        TextLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -Config.dateOffset

            text: Clock.date
            font.family: Config.fontFamilyClock
            font.weight: Font.DemiBold
            font.pixelSize: Config.dateSize
        }

        Avatar {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -Config.avatarOffset
        }

        InputField {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -Config.fieldOffset
        }

        UserTag {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Config.userOffset
        }
    }
}
