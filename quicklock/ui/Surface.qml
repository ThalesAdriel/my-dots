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

    // pointChanged also fires for a pointer that has not moved: Qt redelivers hover to a stationary cursor whenever the scene changes under it, and the field's own fade is such a change, so the fade woke the field it had just put to sleep and the input blinked in a loop. Only a displacement from the last position that counted is activity; the slack also swallows sensor jitter on a mouse that is not being touched.
    HoverHandler {
        id: pointer

        property point lastCounted: Qt.point(NaN, NaN)

        onPointChanged: {
            const p = pointer.point.position;
            if (isNaN(pointer.lastCounted.x) || Math.abs(p.x - pointer.lastCounted.x) + Math.abs(p.y - pointer.lastCounted.y) >= 4) {
                pointer.lastCounted = p;
                pointerSettle.start();
            }
        }
    }

    // A pointer reports at up to a thousand hertz and every report was restarting a two second fade timer. start() rather than restart(), so one that never stops moving still reports in: a tenth of a second is finer than anything reading this, and the last move of a gesture is the one that arms the fade either way.
    Timer {
        id: pointerSettle

        interval: 100
        onTriggered: Auth.activity()
    }

    Item {
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
