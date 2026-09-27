import QtQuick
import qs.config
import qs.services

Item {
    id: root

    readonly property int pad: 9

    implicitWidth: Config.caffeineSize + root.pad * 2
    implicitHeight: Config.caffeineSize + root.pad * 2

    scale: hover.hovered ? 1.1 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Config.animFast
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        anchors.fill: parent

        radius: Config.radius(Config.rounding, height)
        color: Caffeine.active ? Config.entryBackground : "transparent"
        border.width: Config.outlineThickness
        border.color: Caffeine.broken ? Config.failColor : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Config.animFast
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Config.animFast
            }
        }
    }

    Text {
        anchors.centerIn: parent

        text: Config.caffeineIcon
        color: Config.text
        opacity: Caffeine.active ? 1 : 0.45
        font.family: Config.fontFamilyIcons
        font.weight: Font.Black
        font.pixelSize: Config.caffeineSize

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animFast
            }
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Caffeine.toggle()
    }
}
