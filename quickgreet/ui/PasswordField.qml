import QtQuick
import qs.config
import qs.services

// quicklock's password field.
Field {
    id: root

    readonly property int padding: 11
    readonly property int slot: Config.dotSize + Config.dotSpacing
    readonly property int maxDots: Math.max(1, Math.floor((root.width - root.padding * 2) / root.slot))

    // Tab, Shift+Tab or Up: back to the login.
    signal back

    focused: root.activeFocus
    outline: {
        if (Auth.busy)
            return Config.check;
        if (Auth.failed)
            return Config.fail;
        if (root.activeFocus && CapsLock.active)
            return Config.caps;
        return root.activeFocus ? Config.focus : "transparent";
    }

    Accessible.role: Accessible.EditableText
    Accessible.name: Auth.prompt || "Password"
    Accessible.passwordEdit: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab || event.key === Qt.Key_Up) {
            event.accepted = true;
            root.back();
            return;
        }
        Auth.handleKey(event);
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: root.forceActiveFocus()
    }

    Connections {
        target: Auth

        function onBufferChanged() {
            if (Auth.length > 0)
                root.tap();
        }

        function onRejected() {
            root.shake();
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.verticalCenter: parent.verticalCenter

        opacity: Auth.length === 0 ? 1 : 0
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: Auth.prompt || "Password"
        color: Config.muted
        font.family: Config.fontFamily
        font.pixelSize: Config.textSize

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animFast
            }
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: root.padding
        anchors.verticalCenter: parent.verticalCenter

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
                    radius: Config.radius(Config.rounding, height)
                    color: Config.text

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
