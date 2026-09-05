pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import "root:/config"
import "root:/components"

Item {
    id: root

    property bool expanded: false
    property real expansion: root.expanded ? 1 : 0

    readonly property var streams: {
        if (!Pipewire.nodes)
            return [];
        return Pipewire.nodes.values.filter(node => node && node.isStream && node.audio !== null);
    }

    readonly property int rowHeight: 46

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

    implicitHeight: header.height + (streamsColumn.implicitHeight + 8) * root.expansion
    clip: true

    Behavior on expansion {
        NumberAnimation {
            duration: Theme.durationSlow
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easingCurve
        }
    }

    PwObjectTracker {
        objects: root.streams
    }

    Rectangle {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        height: 34
        radius: Theme.radius
        color: headerMouse.containsPress ? Theme.fillPressed : headerMouse.containsMouse ? Theme.fillHover : "transparent"

        IconText {
            id: expandMark

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            fillBarHeight: false

            text: Glyphs.angleRight
            color: Theme.textMuted
            font.pixelSize: 10
            rotation: root.expansion * 90
        }

        Text {
            anchors.left: expandMark.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "Application volume"
            color: Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: String(root.streams.length)
            color: Theme.textMuted
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    Item {
        anchors.top: header.bottom
        anchors.topMargin: 8 * root.expansion
        anchors.left: parent.left
        anchors.right: parent.right

        height: streamsColumn.implicitHeight * root.expansion
        clip: true

        Column {
            id: streamsColumn

            width: parent.width
            spacing: 6
            y: (root.expansion - 1) * 14
            opacity: root.expansion

            Text {
                width: streamsColumn.width
                height: 30
                visible: root.streams.length === 0
                text: "Nothing playing audio"
                color: Theme.textMuted
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: root.streams

                delegate: Item {
                    id: streamRow

                    required property var modelData

                    readonly property bool ready: streamRow.modelData.ready && streamRow.modelData.audio !== null

                    width: streamsColumn.width
                    height: root.rowHeight

                    Text {
                        id: streamName

                        anchors.left: parent.left
                        anchors.right: streamValue.left
                        anchors.top: parent.top
                        anchors.leftMargin: 6
                        anchors.rightMargin: 8

                        text: root.describe(streamRow.modelData)
                        color: Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    Text {
                        id: streamValue

                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 6

                        width: 38
                        horizontalAlignment: Text.AlignRight
                        text: streamRow.ready ? Math.round(streamRow.modelData.audio.volume * 100) + "%" : "--"
                        color: Theme.textMuted
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Rectangle {
                        id: streamMute

                        anchors.left: parent.left
                        anchors.bottom: parent.bottom

                        width: Theme.iconSize + 10
                        height: 20
                        radius: Theme.radius
                        color: streamMuteMouse.containsPress ? Theme.fillPressed : streamMuteMouse.containsMouse ? Theme.fillHover : "transparent"

                        IconText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            fillBarHeight: false
                            horizontalAlignment: Text.AlignLeft

                            text: streamRow.ready && streamRow.modelData.audio.muted ? Glyphs.volumeOff : Glyphs.volumeHigh
                            color: streamRow.ready && streamRow.modelData.audio.muted ? Theme.textMuted : Theme.textPrimary
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        MouseArea {
                            id: streamMuteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: streamRow.ready
                            onClicked: streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
                        }
                    }

                    LevelSlider {
                        anchors.left: streamMute.right
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        anchors.bottomMargin: 2

                        maximum: 1.0
                        value: streamRow.ready ? streamRow.modelData.audio.volume : 0
                        fillColor: streamRow.ready && streamRow.modelData.audio.muted ? Theme.textMuted : Theme.accent

                        onMoved: newValue => {
                            if (streamRow.ready)
                                streamRow.modelData.audio.volume = newValue;
                        }
                    }
                }
            }
        }
    }
}
