pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Item {
    id: stepperRow

    property string label: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 1
    property int decimals: 0

    property bool applies: true
    readonly property bool hit: stepperRow.applies && SettingsContext.shows(stepperRow, stepperRow.label)

    signal adjusted(real newValue)

    // Rounded to the shown decimals, so a hundred steps of 0.01 land on a number rather than on 0.9999999.
    function nudge(direction: int): void {
        const next = Math.min(Math.max(stepperRow.value + direction * stepperRow.step, stepperRow.minimum), stepperRow.maximum);
        stepperRow.adjusted(Number(next.toFixed(stepperRow.decimals)));
    }

    width: parent.width
    height: 34
    visible: stepperRow.hit

    RowLabel {
        anchors.left: parent.left
        anchors.right: stepper.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: stepperRow.label
    }

    Row {
        id: stepper

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            width: 54
            height: 26
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            text: stepperRow.value.toFixed(stepperRow.decimals)
            color: Theme.textPrimary
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        PanelButton {
            label: "−"
            implicitWidth: 26
            onActivated: stepperRow.nudge(-1)
        }

        PanelButton {
            label: "+"
            implicitWidth: 26
            onActivated: stepperRow.nudge(1)
        }
    }
}
