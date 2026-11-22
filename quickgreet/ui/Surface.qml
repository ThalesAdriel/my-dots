import QtQuick
import Quickshell
import qs.config
import qs.services

// Everything over the background on the output that gets the card, laid out as the mockup has it.
Item {
    id: root

    property bool menuOpen: false
    readonly property alias battery: battery

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
            id: cornerHolder

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
                    visible: Config.showSessionMenu
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
                    model: Config.showPowerButtons ? [
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
                    ] : []

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

                open: Config.showSessionMenu && root.menuOpen
                onPicked: root.menuOpen = false
            }
        }

        // Clock & date aligned with the login card, clear of both the card and top-right corner buttons.
        Item {
            id: clockHolder

            visible: Config.showClock
            readonly property real cardTop: (parent.height - cardHolder.height * root.factor) / 2
            readonly property real minY: Config.cardPosition === "right"
                ? 20 + cornerHolder.height * root.factor + 16 * root.factor
                : Math.max(20 * root.factor, Config.preview ? 56 : 0)

            x: Config.cardPosition === "left"
                ? Math.round(parent.width * 0.08)
                : (Config.cardPosition === "right"
                    ? Math.round(parent.width * 0.92 - width)
                    : Math.round((parent.width - width) / 2))
            y: Math.max(minY, minY + (cardTop - minY - height * root.factor) / 2)
            width: clockColumn.implicitWidth
            height: clockColumn.implicitHeight

            transformOrigin: Config.cardPosition === "left"
                ? Item.TopLeft
                : (Config.cardPosition === "right" ? Item.TopRight : Item.Top)
            scale: root.factor

            Column {
                id: clockColumn

                readonly property int textAlign: Config.cardPosition === "left"
                    ? Text.AlignLeft
                    : (Config.cardPosition === "right" ? Text.AlignRight : Text.AlignHCenter)
                readonly property real contentWidth: Math.max(clockTime.implicitWidth, clockDate.implicitWidth)

                spacing: 4

                Text {
                    id: clockTime

                    width: clockColumn.contentWidth
                    horizontalAlignment: clockColumn.textAlign
                    text: Clock.time
                    color: Config.text
                    font.family: Config.fontFamilyClock
                    font.pixelSize: Config.clockSize
                    font.weight: Font.DemiBold
                }

                Text {
                    id: clockDate

                    width: clockColumn.contentWidth
                    horizontalAlignment: clockColumn.textAlign
                    text: Clock.date
                    color: Config.text
                    font.family: Config.fontFamilyClock
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }
            }
        }

        // Battery indicator in the bottom-right status corner, clear of power buttons and session menu.
        BatteryLabel {
            id: battery

            visible: Config.showBattery && battery.present
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20

            transformOrigin: Item.BottomRight
            scale: root.factor
        }

        // The card has its own scale for the entrance, so the screen's goes on this.
        Item {
            id: cardHolder

            anchors.verticalCenter: parent.verticalCenter
            x: Config.cardPosition === "left"
                ? Math.round(parent.width * 0.08)
                : (Config.cardPosition === "right"
                    ? Math.round(parent.width * 0.92 - width)
                    : Math.round((parent.width - width) / 2))
            width: card.width
            height: card.height

            transformOrigin: Config.cardPosition === "left"
                ? Item.Left
                : (Config.cardPosition === "right" ? Item.Right : Item.Center)
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
