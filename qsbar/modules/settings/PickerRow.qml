pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

Column {
    id: pickerRow

    property string label: ""
    property var options: []
    property string current: ""
    property bool open: false

    // What an option reads as, where the value is not something to show.
    property var labelOf: value => value

    property bool applies: true
    readonly property bool hit: pickerRow.applies && SettingsContext.shows(pickerRow, pickerRow.label)

    signal picked(string value)

    // The arrows on the closed button walk the list the way a select does, taking each one as they reach it.
    function step(delta: int): void {
        if (pickerRow.options.length === 0)
            return;
        const index = pickerRow.options.indexOf(pickerRow.current);
        const next = Math.min(Math.max(index < 0 ? 0 : index + delta, 0), pickerRow.options.length - 1);
        if (pickerRow.options[next] !== pickerRow.current)
            pickerRow.picked(pickerRow.options[next]);
    }

    width: parent.width
    spacing: 4
    visible: pickerRow.hit

    Item {
        width: parent.width
        height: 34

        RowLabel {
            anchors.left: parent.left
            anchors.right: pickerButton.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: pickerRow.label
        }

        Rectangle {
            id: pickerButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: Math.min(300, pickerRow.width * 0.62)
            height: 28
            radius: Theme.radius
            color: pickerMouse.containsPress ? Theme.fillPressed : pickerMouse.containsMouse ? Theme.fillHover : Theme.fillTrack

            activeFocusOnTab: true
            Keys.onUpPressed: pickerRow.step(-1)
            Keys.onDownPressed: pickerRow.step(1)
            Keys.onSpacePressed: pickerRow.open = !pickerRow.open
            Keys.onReturnPressed: pickerRow.open = !pickerRow.open
            Keys.onEnterPressed: pickerRow.open = !pickerRow.open

            FocusRing {}

            Text {
                anchors.left: parent.left
                anchors.right: pickerChevron.left
                anchors.leftMargin: 9
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter

                textFormat: Text.PlainText
                text: pickerRow.current !== "" ? pickerRow.labelOf(pickerRow.current) : "Not set"
                color: pickerRow.current !== "" ? Theme.textPrimary : Theme.textMuted
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            IconText {
                id: pickerChevron

                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter

                fillBarHeight: false
                text: pickerRow.open ? Glyphs.angleDown : Glyphs.angleRight
                color: Theme.textMuted
                font.pixelSize: 9
            }

            MouseArea {
                id: pickerMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: pickerRow.open = !pickerRow.open
            }
        }
    }

    // Scrolled by the wheel alone, and the scroller under the list rather than over it.
    Item {
        width: parent.width
        height: pickerList.height
        visible: pickerRow.open && pickerList.count > 0

        WheelScroller {
            anchors.fill: parent
            target: pickerList
        }

        ListView {
            id: pickerList

            width: parent.width
            height: Math.min(pickerList.count, 8) * 30

            clip: true
            spacing: 2
            interactive: false
            model: pickerRow.options

            // Opened on the one already in use rather than at the top of a list that can run to dozens.
            onVisibleChanged: {
                if (pickerList.visible)
                    pickerList.positionViewAtIndex(Math.max(pickerRow.options.indexOf(pickerRow.current), 0), ListView.Center);
            }

            delegate: Rectangle {
                id: option

                required property string modelData

                readonly property bool chosen: option.modelData === pickerRow.current

                width: pickerList.width
                height: 28
                radius: Theme.radius
                color: {
                    if (optionMouse.containsPress)
                        return Theme.fillPressed;
                    if (optionMouse.containsMouse)
                        return Theme.fillHover;
                    return option.chosen ? Theme.fillTrack : "transparent";
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: optionCheck.left
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    textFormat: Text.PlainText
                    text: pickerRow.labelOf(option.modelData)
                    color: option.chosen ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                IconText {
                    id: optionCheck

                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    fillBarHeight: false
                    visible: option.chosen
                    text: Glyphs.check
                    color: Theme.accent
                    font.pixelSize: 10
                }

                MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        pickerRow.open = false;
                        if (!option.chosen)
                            pickerRow.picked(option.modelData);
                    }
                }
            }
        }
    }
}
