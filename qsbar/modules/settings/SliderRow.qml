pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Item {
    id: sliderRow

    property string label: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property int decimals: 0
    property string suffix: ""

    // What the number on the right reads.
    property string valueText: sliderRow.value.toFixed(sliderRow.decimals) + sliderRow.suffix

    // Set false where the row only means something some of the time, rather than overriding `visible`.
    property bool applies: true
    readonly property bool hit: sliderRow.applies && SettingsContext.shows(sliderRow, sliderRow.label)

    signal adjusted(real newValue)

    width: parent.width
    height: 42
    visible: sliderRow.hit

    RowLabel {
        anchors.left: parent.left
        anchors.top: parent.top
        text: sliderRow.label
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: sliderRow.valueText
        color: Theme.textPrimary
        font.family: Theme.monoFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    LevelSlider {
        id: slider

        // A twentieth of the range a press.
        readonly property real keyStep: Math.max((sliderRow.maximum - sliderRow.minimum) / 20, sliderRow.decimals === 0 ? 1 : 0)

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        maximum: 1
        value: sliderRow.maximum > sliderRow.minimum ? (sliderRow.value - sliderRow.minimum) / (sliderRow.maximum - sliderRow.minimum) : 0

        onMoved: newValue => sliderRow.adjusted(sliderRow.minimum + newValue * (sliderRow.maximum - sliderRow.minimum))

        activeFocusOnTab: true
        Keys.onLeftPressed: sliderRow.adjusted(Math.max(sliderRow.value - slider.keyStep, sliderRow.minimum))
        Keys.onRightPressed: sliderRow.adjusted(Math.min(sliderRow.value + slider.keyStep, sliderRow.maximum))

        FocusRing {}
    }
}
