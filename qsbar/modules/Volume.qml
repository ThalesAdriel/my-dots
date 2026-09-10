import QtQuick
import Quickshell.Services.Pipewire
import "root:/config"
import "root:/components"

BarButton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool sinkReady: root.sink !== null && root.sink.ready && root.sink.audio !== null
    readonly property real sinkVolume: root.sinkReady ? root.sink.audio.volume : 0
    readonly property bool sinkMuted: root.sinkReady && root.sink.audio.muted

    readonly property bool sourceReady: root.source !== null && root.source.ready && root.source.audio !== null
    readonly property bool sourceMuted: root.sourceReady && root.source.audio.muted

    readonly property real maximumVolume: 1.5
    readonly property real volumeStep: 0.1

    highlighted: volumePopup.shown

    onScrolled: steps => root.applyVolumeDelta(steps)
    onPrimaryClicked: volumePopup.toggle()
    onSecondaryClicked: {
        if (root.sinkReady)
            root.sink.audio.muted = !root.sinkMuted;
    }

    onSinkVolumeChanged: levelTimer.restart()
    onSinkMutedChanged: levelTimer.restart()

    function applyVolumeDelta(steps: int): void {
        if (!root.sinkReady)
            return;
        const target = root.sinkVolume + steps * root.volumeStep;
        root.sink.audio.volume = Math.min(Math.max(target, 0), root.maximumVolume);
        levelTimer.restart();
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Timer {
        id: levelTimer
        interval: 1400
    }

    Timer {
        id: sinkSettle

        property bool expired: false

        interval: 1500
        running: true
        onTriggered: sinkSettle.expired = true
    }

    IconStack {
        IconText {
            anchors.centerIn: parent
            opacity: root.sinkReady ? 1 : 0
            text: {
                if (root.sinkMuted || root.sinkVolume <= 0.001)
                    return Glyphs.volumeOff;
                if (root.sinkVolume < 0.5)
                    return Glyphs.volumeLow;
                return Glyphs.volumeHigh;
            }
            color: root.sinkMuted ? Theme.textMuted : Theme.textPrimary

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }
    }

    IconStack {
        slotWidth: Theme.fontSizeSmall + 2
        visible: root.sourceReady && root.sourceMuted

        IconText {
            anchors.centerIn: parent
            text: Glyphs.microphoneMuted
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    overlayContent: [
        Skeleton {
            anchors.centerIn: parent
            width: 16
            height: 12
            active: !root.sinkReady && !sinkSettle.expired
        },

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4

            width: parent.width - 14
            height: 2
            radius: Theme.pill(2)
            color: Theme.fillTrack

            opacity: levelTimer.running ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                height: parent.height
                radius: parent.radius
                width: parent.width * Math.min(root.sinkVolume / root.maximumVolume, 1)
                color: root.sinkMuted ? Theme.textMuted : Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durationFast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                }
            }
        }
    ]

    BarPopup {
        id: volumePopup

        anchorItem: root
        alignRight: true

        Loader {
            active: volumePopup.rendered

            sourceComponent: VolumePanel {
                active: volumePopup.rendered
            }
        }
    }

    BarTooltip {
        anchorItem: root
        shown: root.containsMouse && root.sinkReady && !volumePopup.shown
        text: {
            if (!root.sinkReady)
                return "";
            const level = root.sinkMuted ? "muted" : Math.round(root.sinkVolume * 100) + "%";
            const microphone = root.sourceReady && root.sourceMuted ? ", mic muted" : "";
            return "Volume " + level + microphone;
        }
    }
}
