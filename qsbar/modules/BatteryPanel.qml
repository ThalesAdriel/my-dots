pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

// Everything the battery knows about itself is handed in rather than read here, so Quickshell.Services.UPower stays confined to the one file that can be loaded without it.
Item {
    id: root

    property bool present: false
    property real level: 0
    property int percent: 0
    property string stateLabel: ""
    property string timeLabel: ""
    property bool low: false
    property bool charging: false
    property int health: 0

    readonly property int panelPadding: 16
    readonly property int panelWidth: 300

    implicitWidth: root.panelWidth
    implicitHeight: content.implicitHeight + root.panelPadding * 2

    Column {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.panelPadding

        spacing: 12

        Card {
            width: parent.width
            height: 76

            Text {
                id: levelReading

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 14
                anchors.topMargin: 12

                text: root.present ? root.percent + "%" : "--"
                color: root.low ? Theme.urgent : Theme.textPrimary
                font.family: Theme.monoFamily
                font.pixelSize: 22
                font.weight: Theme.fontWeightStrong
            }

            Text {
                anchors.left: levelReading.right
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 14
                anchors.baseline: levelReading.baseline

                text: root.stateLabel + (root.timeLabel !== "" ? ", " + root.timeLabel : "")
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            // The charge as a bar, so the number is not the only thing to read.
            Rectangle {
                id: track

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.bottomMargin: 18

                height: 4
                radius: Theme.pill(4)
                color: Theme.fillTrack

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top

                    height: parent.height
                    radius: parent.radius
                    width: parent.width * Math.min(Math.max(root.level, 0), 1)
                    color: {
                        if (root.low)
                            return Theme.urgent;
                        return root.charging ? Theme.accent : Theme.textPrimary;
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durationBase
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easingCurve
                        }
                    }
                }
            }

            Text {
                anchors.left: track.left
                anchors.top: track.bottom
                anchors.topMargin: 4

                visible: root.present && root.health > 0
                text: "Health " + root.health + "%"
                color: Theme.textMuted
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Text {
            width: parent.width
            text: "Power profile"
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightStrong
            font.capitalization: Font.AllUppercase
            visible: PowerProfiles.available
        }

        Column {
            width: parent.width
            spacing: 6
            visible: PowerProfiles.available

            Repeater {
                model: PowerProfiles.sortedProfiles

                delegate: Rectangle {
                    id: profileRow

                    required property string modelData

                    readonly property bool selected: PowerProfiles.active === profileRow.modelData

                    width: parent.width
                    height: 38
                    radius: Theme.radius

                    color: {
                        if (profileMouse.containsPress)
                            return Theme.fillPressed;
                        if (profileMouse.containsMouse)
                            return Theme.fillHover;
                        return profileRow.selected ? Theme.accent : Theme.fillTrack;
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durationFast
                        }
                    }

                    IconText {
                        id: profileGlyph

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        fillBarHeight: false
                        text: PowerProfiles.glyph(profileRow.modelData)
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        anchors.left: profileGlyph.right
                        anchors.right: profileMark.left
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        text: PowerProfiles.label(profileRow.modelData)
                        color: Theme.textPrimary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: profileRow.selected ? Theme.fontWeightStrong : Theme.fontWeightNormal
                        elide: Text.ElideRight
                    }

                    IconText {
                        id: profileMark

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 12

                        fillBarHeight: false
                        visible: profileRow.selected
                        text: Glyphs.check
                        color: Theme.textPrimary
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: profileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: PowerProfiles.set(profileRow.modelData)
                    }
                }
            }
        }

        PanelMessage {
            width: parent.width
            visible: !PowerProfiles.available
            text: "powerprofilesctl was not found. Profiles need power-profiles-daemon."
        }

        PanelMessage {
            width: parent.width
            visible: PowerProfiles.lastError !== ""
            warning: true
            text: PowerProfiles.lastError
        }
    }
}
