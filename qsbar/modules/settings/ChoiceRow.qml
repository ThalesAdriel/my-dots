pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Item {
    id: choiceRow

    property string label: ""
    property var options: []
    property var current

    property bool applies: true
    readonly property bool hit: choiceRow.applies && SettingsContext.shows(choiceRow, choiceRow.label)

    signal picked(var value)

    width: parent.width
    height: 34
    visible: choiceRow.hit

    RowLabel {
        anchors.left: parent.left
        anchors.right: choices.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: choiceRow.label
    }

    FocusRing {
        target: choices
    }

    Row {
        id: choices

        function step(delta: int): void {
            let index = -1;
            for (let at = 0; at < choiceRow.options.length; at++) {
                if (choiceRow.options[at].value === choiceRow.current)
                    index = at;
            }
            const next = Math.min(Math.max(index < 0 ? 0 : index + delta, 0), choiceRow.options.length - 1);
            choiceRow.picked(choiceRow.options[next].value);
        }

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        activeFocusOnTab: true
        Keys.onLeftPressed: choices.step(-1)
        Keys.onRightPressed: choices.step(1)

        Repeater {
            model: choiceRow.options

            delegate: Rectangle {
                id: choice

                required property var modelData

                readonly property bool chosen: choiceRow.current === choice.modelData.value

                width: choiceLabel.implicitWidth + 20
                height: 24
                radius: Theme.radius
                color: {
                    if (choiceMouse.containsPress)
                        return Theme.fillPressed;
                    if (choiceMouse.containsMouse)
                        return Theme.fillHover;
                    return choice.chosen ? Theme.accent : Theme.fillTrack;
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }

                Text {
                    id: choiceLabel
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: choice.modelData.label
                    color: choice.chosen ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightNormal
                }

                MouseArea {
                    id: choiceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: choiceRow.picked(choice.modelData.value)
                }
            }
        }
    }
}
