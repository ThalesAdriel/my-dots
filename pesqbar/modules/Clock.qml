import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

BarButton {
    id: root

    readonly property int currentMinute: clock.date.getMinutes()

    interactive: false
    leftPadding: 8
    rightPadding: 12

    onCurrentMinuteChanged: root.restartMinuteProgress()
    Component.onCompleted: root.restartMinuteProgress()

    // The line is a minute long, so leaving it running with the setting off
    // means a property animation ticking every frame for something nothing is
    // drawing.
    function restartMinuteProgress(): void {
        progressAnimation.stop();
        if (!Settings.clockShowProgress)
            return;

        const seconds = clock.date.getSeconds();
        progressAnimation.from = seconds / 60;
        progressAnimation.to = 1;
        progressAnimation.duration = Math.max((60 - seconds) * 1000, 1);
        progressAnimation.start();
    }

    Connections {
        target: Settings

        function onClockShowProgressChanged(): void {
            root.restartMinuteProgress();
        }
    }

    SystemClock {
        id: clock
        precision: Settings.clockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
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
            id: progressFill

            property real fraction: 0

            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width * Math.min(Math.max(progressFill.fraction, 0), 1)
            height: parent.height
            color: Theme.textPrimary
            opacity: 0.45

            NumberAnimation {
                id: progressAnimation
                target: progressFill
                property: "fraction"
                easing.type: Easing.Linear
            }
        }
    }
}
