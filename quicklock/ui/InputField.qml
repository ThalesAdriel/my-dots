import QtQuick
import qs.config
import qs.services

Item {
    id: root

    readonly property int outline: Config.outlineThickness
    readonly property int slot: Config.dotSize + Config.dotSpacing
    readonly property int maxDots: Math.max(1, Math.floor((Config.fieldWidth - Config.dotSize) / root.slot))
    readonly property bool showHint: Auth.failed || (Auth.length === 0 && !Auth.busy)

    property bool awake: true

    implicitWidth: Config.fieldWidth + root.outline * 2
    implicitHeight: Config.fieldHeight + root.outline * 2

    opacity: (!Config.fadeOnEmpty || root.awake || Auth.length > 0 || Auth.busy || Auth.failed) ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Config.fadeDuration
            easing.type: Easing.InOutQuad
        }
    }

    Timer {
        id: idle
        interval: Config.fadeTimeout
        running: Config.fadeOnEmpty
        onTriggered: root.awake = false
    }

    Connections {
        target: Auth

        function onActivity() {
            root.awake = true;
            if (Config.fadeOnEmpty)
                idle.restart();
        }

        function onBufferChanged() {
            if (Auth.length > 0)
                tap.restart();
        }

        function onRejected() {
            shake.restart();
        }
    }

    Rectangle {
        id: field

        property real press: 1
        property real shift: 0

        anchors.fill: parent

        radius: Config.radius(Config.rounding, height)
        color: Config.entryBackground
        border.width: root.outline
        border.color: Auth.busy ? Config.checkColor : Auth.failed ? Config.failColor : CapsLock.active ? Config.capsColor : Config.entryBorder

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
            id: tap

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
            id: shake

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

        Text {
            anchors.centerIn: parent

            visible: root.showHint
            opacity: root.showHint ? 1 : 0
            width: Config.fieldWidth - Config.dotSize
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.StyledText
            color: Config.entryText
            font.family: Config.fontFamily
            font.pixelSize: Config.hintSize
            text: Auth.failed ? Auth.failText : Config.placeholderText

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animFast
                }
            }
        }

        Row {
            anchors.centerIn: parent

            visible: !root.showHint
            spacing: 0

            Repeater {
                model: root.maxDots

                Item {
                    id: cell

                    required property int index
                    readonly property bool filled: cell.index < Auth.length

                    width: cell.filled ? root.slot : 0
                    height: Config.dotSize

                    Behavior on width {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent

                        width: Config.dotSize
                        height: Config.dotSize
                        radius: Config.radius(Config.dotRounding, height)
                        color: Config.entryText

                        opacity: cell.filled ? 1 : 0
                        scale: cell.filled ? 1 : 0.2

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 130
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                            }
                        }
                    }
                }
            }
        }
    }
}
