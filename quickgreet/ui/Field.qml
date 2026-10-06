import QtQuick
import qs.config

// What both fields share with quicklock's.
Rectangle {
    id: field

    property real press: 1
    property real shift: 0
    property color outline: field.focused ? Config.focus : "transparent"
    property bool focused: false

    function tap() {
        tapAnimation.restart();
    }

    function shake() {
        shakeAnimation.restart();
    }

    width: Config.fieldWidth
    height: Config.fieldHeight

    radius: Config.radius(Config.rounding, height)
    color: Config.field
    border.width: Config.outlineThickness
    border.color: field.outline

    scale: field.press
    transform: Translate {
        x: field.shift
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Config.animFast
        }
    }

    SequentialAnimation {
        id: tapAnimation

        NumberAnimation {
            target: field
            property: "press"
            to: 1.03
            duration: 70
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: field
            property: "press"
            to: 1.0
            duration: 130
            easing.type: Easing.OutQuad
        }
    }

    SequentialAnimation {
        id: shakeAnimation

        NumberAnimation {
            target: field
            property: "shift"
            to: -10
            duration: 55
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: field
            property: "shift"
            to: 10
            duration: 70
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: field
            property: "shift"
            to: -5
            duration: 60
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: field
            property: "shift"
            to: 0
            duration: 60
            easing.type: Easing.OutQuad
        }
    }
}
