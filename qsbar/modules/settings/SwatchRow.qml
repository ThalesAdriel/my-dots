pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Column {
    id: swatchRow

    property string label: ""
    property var options: []
    property string current: ""
    property bool picking: false

    // A colour that is none of the swatches, picked with the picker or typed into the file by hand.
    readonly property bool custom: swatchRow.current !== "" && swatchRow.options.indexOf(swatchRow.current.toLowerCase()) === -1

    property bool applies: true
    readonly property bool hit: swatchRow.applies && SettingsContext.shows(swatchRow, swatchRow.label)

    signal picked(string value)

    width: parent.width
    spacing: 4
    visible: swatchRow.hit

    Item {
        width: parent.width
        height: 34

        RowLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: swatchRow.label
        }

        // One Tab stop for the row, like a set of radio buttons, with the arrows walking the choice and Enter opening the picker.
        FocusRing {
            target: swatches
        }

        Row {
            id: swatches

            function step(delta: int): void {
                const index = swatchRow.options.indexOf(swatchRow.current.toLowerCase());
                const next = Math.min(Math.max(index < 0 ? 0 : index + delta, 0), swatchRow.options.length - 1);
                swatchRow.picked(swatchRow.options[next]);
            }

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            activeFocusOnTab: true
            Keys.onLeftPressed: swatches.step(-1)
            Keys.onRightPressed: swatches.step(1)
            Keys.onReturnPressed: swatchRow.picking = !swatchRow.picking
            Keys.onEnterPressed: swatchRow.picking = !swatchRow.picking
            Keys.onSpacePressed: swatchRow.picking = !swatchRow.picking

            Repeater {
                model: swatchRow.options

                delegate: Rectangle {
                    id: swatch

                    required property string modelData

                    readonly property bool chosen: swatchRow.current.toLowerCase() === swatch.modelData

                    width: 22
                    height: 22
                    radius: Theme.radius
                    color: swatch.modelData
                    border.width: swatch.chosen ? 2 : 1
                    border.color: swatch.chosen ? Theme.textPrimary : Theme.cardBorder

                    MouseArea {
                        anchors.fill: parent
                        onClicked: swatchRow.picked(swatch.modelData)
                    }
                }
            }

            // Any other colour: shows it once one is in use, and opens the picker either way.
            Rectangle {
                width: 22
                height: 22
                radius: Theme.radius
                color: swatchRow.custom ? swatchRow.current : customMouse.containsMouse ? Theme.fillHover : Theme.fillTrack
                border.width: swatchRow.custom || swatchRow.picking ? 2 : 1
                border.color: swatchRow.custom || swatchRow.picking ? Theme.textPrimary : Theme.cardBorder

                IconText {
                    anchors.centerIn: parent
                    fillBarHeight: false
                    visible: !swatchRow.custom
                    text: swatchRow.picking ? Glyphs.xmark : Glyphs.plus
                    color: Theme.textSecondary
                    font.pixelSize: 10
                }

                MouseArea {
                    id: customMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: swatchRow.picking = !swatchRow.picking
                }
            }
        }
    }

    Loader {
        width: parent.width
        active: swatchRow.picking
        visible: active

        sourceComponent: ColorPicker {
            value: swatchRow.current
            onPicked: value => swatchRow.picked(value)
        }
    }
}
