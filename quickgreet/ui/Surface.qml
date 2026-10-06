import QtQuick
import Quickshell
import qs.config
import qs.services

// Everything over the background on the output that gets the card, laid out as the mockup has it.
Item {
    id: root

    property bool menuOpen: false

    // The mockup was drawn at 1080 lines.
    readonly property real factor: Config.uiScale * root.height / 1080

    // A preview has nothing to turn off: each of these closes it instead.
    function power(action) {
        if (Config.preview)
            Qt.quit();
        else
            Quickshell.execDetached(["systemctl", action]);
    }

    // After the window has mapped, or the focus lands on a surface that does not have the keyboard yet.
    Component.onCompleted: Qt.callLater(card.focusStart)

    MouseArea {
        anchors.fill: parent
        onClicked: root.menuOpen = false
    }

    Item {
        anchors.fill: parent

        opacity: Auth.launching ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animNormal
                easing.type: Easing.OutQuad
            }
        }

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 24

            visible: Config.preview
            text: "Preview: nothing is launched, Esc on an empty field or any power button closes it"
            color: Config.muted
            font.family: Config.fontFamily
            font.pixelSize: Config.textSize - 2
        }

        // The corner, scaled from the corner itself so it stays put while it shrinks.
        Item {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            width: corner.width
            height: corner.height

            transformOrigin: Item.TopRight
            scale: root.factor

            Row {
                id: corner

                anchors.right: parent.right
                spacing: 10

                Tile {
                    width: Config.cornerSize
                    height: Config.cornerSize
                    glyph: ""
                    label: "Sessions"
                    glyphSize: 26
                    lit: root.menuOpen
                    onClicked: root.menuOpen = !root.menuOpen
                }

                Tile {
                    width: Config.cornerSize
                    height: Config.cornerSize
                    glyph: ""
                    label: "Keep awake"
                    glyphSize: 24
                    lit: Caffeine.active
                    warning: Caffeine.broken
                    onClicked: Caffeine.toggle()
                }

                Repeater {
                    model: [
                        {
                            glyph: "",
                            label: "Suspend",
                            action: "suspend"
                        },
                        {
                            glyph: "",
                            label: "Restart",
                            action: "reboot"
                        },
                        {
                            glyph: "",
                            label: "Power off",
                            action: "poweroff"
                        }
                    ]

                    Tile {
                        required property var modelData

                        width: Config.cornerSize
                        height: Config.cornerSize
                        glyph: modelData.glyph
                        label: modelData.label
                        glyphSize: 24
                        onClicked: root.power(modelData.action)
                    }
                }
            }

            SessionMenu {
                // Lined up under the gear, the first of the row.
                anchors.left: corner.left
                anchors.top: corner.bottom
                anchors.topMargin: 2

                open: root.menuOpen
                onPicked: root.menuOpen = false
            }
        }

        // The card has its own scale for the entrance, so the screen's goes on this.
        Item {
            anchors.centerIn: parent
            width: Config.cardWidth
            height: Config.cardHeight

            scale: root.factor

            LoginCard {
                id: card

                anchors.centerIn: parent

                opacity: 0
                scale: 0.96

                Component.onCompleted: {
                    card.opacity = 1;
                    card.scale = 1;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutQuad
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }
}
