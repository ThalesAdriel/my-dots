import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

BarButton {
    id: root

    interactive: false
    leftPadding: 8
    rightPadding: 12

    SystemClock {
        id: clock
        precision: Settings.clockShowSeconds || Settings.clockShowProgress ? SystemClock.Seconds : SystemClock.Minutes
    }

    BarText {
        text: Qt.formatDateTime(clock.date, Settings.clockFormat)
        font.family: Theme.monoFamily
    }

    overlayContent: Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5

        width: parent.width - 16
        height: 1
        visible: Settings.clockShowProgress
        color: Theme.fillTrack

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top

            width: parent.width * (clock.date.getSeconds() / 60)
            height: parent.height
            color: Theme.textPrimary
            opacity: 0.45
        }
    }
}
