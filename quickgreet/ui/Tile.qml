import QtQuick
import qs.config

// A square with a glyph that does one thing when clicked: power, the session menu, caffeine, sign in.
Rectangle {
    id: root

    property string glyph: ""
    property string label: ""
    property real glyphSize: 18
    property bool lit: false
    property bool filled: false
    property bool warning: false

    signal clicked

    radius: Config.radius(Config.rounding, Math.min(root.width, root.height))
    color: {
        if (root.lit || root.filled)
            return mouse.containsMouse ? Qt.tint(Config.field, Config.hover) : Config.field;
        return mouse.containsMouse ? Qt.tint(Config.card, Config.hover) : Config.card;
    }
    border.width: Config.outlineThickness
    border.color: root.warning ? Config.fail : "transparent"

    scale: mouse.pressed ? 0.94 : mouse.containsMouse ? 1.04 : 1

    Accessible.role: Accessible.Button
    Accessible.name: root.label

    Behavior on scale {
        NumberAnimation {
            duration: Config.animFast
            easing.type: Easing.OutQuad
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Config.animFast
        }
    }

    Text {
        anchors.centerIn: parent

        text: root.glyph
        color: root.lit || root.filled ? Config.text : Config.line
        font.family: Config.iconFamily
        font.weight: Font.Black
        font.pixelSize: root.glyphSize

        Behavior on color {
            ColorAnimation {
                duration: Config.animFast
            }
        }
    }

    // A MouseArea rather than pointer handlers.
    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
