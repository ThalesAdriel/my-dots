pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import "root:/config"
import "root:/components"

Item {
    id: root

    readonly property int padding: 14
    readonly property int iconSlot: Theme.iconSize + 10
    readonly property real maximumVolume: 1.5

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool sinkReady: root.sink !== null && root.sink.ready && root.sink.audio !== null
    readonly property bool sourceReady: root.source !== null && root.source.ready && root.source.audio !== null

    readonly property var sinkNodes: {
        if (!Pipewire.nodes)
            return [];
        return Pipewire.nodes.values.filter(node => node && node.isSink && !node.isStream && node.audio !== null);
    }

    function describe(node: var): string {
        const candidates = [];
        const props = node.properties;

        if (props) {
            candidates.push(props["application.name"]);
            candidates.push(props["media.name"]);
            candidates.push(props["application.process.binary"]);
            candidates.push(props["node.description"]);
            candidates.push(props["node.name"]);
        }

        candidates.push(node.description);
        candidates.push(node.nickname);
        candidates.push(node.name);

        for (const candidate of candidates) {
            if (typeof candidate === "string" && candidate.length > 0)
                return candidate;
        }
        return "Unknown";
    }

    implicitWidth: 320
    implicitHeight: content.implicitHeight + root.padding * 2

    PwObjectTracker {
        objects: root.sinkNodes
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    Column {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        spacing: 12

        Text {
            text: "Sound"
            color: Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSize
            font.weight: Theme.fontWeightNormal
        }

        Item {
            width: content.width
            height: 22

            Rectangle {
                id: sinkMuteButton

                width: root.iconSlot
                height: 22
                radius: Theme.radius
                color: sinkMuteMouse.containsPress ? Theme.fillPressed : sinkMuteMouse.containsMouse ? Theme.fillHover : "transparent"

                IconText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    fillBarHeight: false
                    horizontalAlignment: Text.AlignLeft
                    text: {
                        if (!root.sinkReady || root.sink.audio.muted)
                            return Glyphs.volumeOff;
                        if (root.sink.audio.volume < 0.5)
                            return Glyphs.volumeLow;
                        return Glyphs.volumeHigh;
                    }
                    color: root.sinkReady && root.sink.audio.muted ? Theme.textMuted : Theme.textPrimary
                }

                MouseArea {
                    id: sinkMuteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.sinkReady
                    onClicked: root.sink.audio.muted = !root.sink.audio.muted
                }
            }

            LevelSlider {
                anchors.left: sinkMuteButton.right
                anchors.leftMargin: 10
                anchors.right: sinkValue.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                maximum: root.maximumVolume
                value: root.sinkReady ? root.sink.audio.volume : 0
                fillColor: root.sinkReady && root.sink.audio.muted ? Theme.textMuted : Theme.accent

                onMoved: newValue => {
                    if (root.sinkReady)
                        root.sink.audio.volume = newValue;
                }
            }

            Text {
                id: sinkValue

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: 38
                horizontalAlignment: Text.AlignRight
                text: root.sinkReady ? Math.round(root.sink.audio.volume * 100) + "%" : "--"
                color: Theme.textSecondary
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Item {
            width: content.width
            height: 22
            visible: root.sourceReady

            Rectangle {
                id: sourceMuteButton

                width: root.iconSlot
                height: 22
                radius: Theme.radius
                color: sourceMuteMouse.containsPress ? Theme.fillPressed : sourceMuteMouse.containsMouse ? Theme.fillHover : "transparent"

                IconText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    fillBarHeight: false
                    horizontalAlignment: Text.AlignLeft
                    text: root.sourceReady && root.source.audio.muted ? Glyphs.microphoneMuted : Glyphs.microphone
                    color: root.sourceReady && root.source.audio.muted ? Theme.textMuted : Theme.textPrimary
                }

                MouseArea {
                    id: sourceMuteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.sourceReady
                    onClicked: root.source.audio.muted = !root.source.audio.muted
                }
            }

            LevelSlider {
                anchors.left: sourceMuteButton.right
                anchors.leftMargin: 10
                anchors.right: sourceValue.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                maximum: 1.0
                value: root.sourceReady ? root.source.audio.volume : 0
                fillColor: root.sourceReady && root.source.audio.muted ? Theme.textMuted : Theme.accent

                onMoved: newValue => {
                    if (root.sourceReady)
                        root.source.audio.volume = newValue;
                }
            }

            Text {
                id: sourceValue

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: 38
                horizontalAlignment: Text.AlignRight
                text: root.sourceReady ? Math.round(root.source.audio.volume * 100) + "%" : "--"
                color: Theme.textSecondary
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Rectangle {
            width: content.width
            height: 1
            color: Theme.popupBorder
        }

        AppVolumeSection {
            width: content.width
            height: implicitHeight
        }

        Rectangle {
            width: content.width
            height: 1
            color: Theme.popupBorder
            visible: root.sinkNodes.length > 1
        }

        Text {
            text: "Outputs"
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            visible: root.sinkNodes.length > 1
        }

        Repeater {
            model: root.sinkNodes.length > 1 ? root.sinkNodes : []

            delegate: Rectangle {
                id: deviceRow

                required property var modelData

                readonly property bool current: root.sink !== null && deviceRow.modelData.id === root.sink.id

                width: content.width
                height: 26
                radius: Theme.radius
                color: deviceMouse.containsPress ? Theme.fillPressed : deviceMouse.containsMouse ? Theme.fillHover : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: currentMark.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter

                    text: root.describe(deviceRow.modelData)
                    color: deviceRow.current ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                Text {
                    id: currentMark

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    text: Glyphs.check
                    color: Theme.accent
                    opacity: deviceRow.current ? 1 : 0
                    font.family: Theme.iconFamily
                    font.weight: Font.Black
                    font.pixelSize: Theme.fontSizeSmall

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durationBase
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easingCurve
                        }
                    }
                }

                MouseArea {
                    id: deviceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Pipewire.preferredDefaultAudioSink = deviceRow.modelData
                }
            }
        }
    }
}
