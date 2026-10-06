import QtQuick
import qs.config
import qs.services

// The card in the middle of the mockup.
Item {
    id: root

    function focusStart() {
        if (Auth.login === "")
            login.input.forceActiveFocus();
        else
            password.forceActiveFocus();
    }

    width: Config.cardWidth
    height: Config.cardHeight

    Rectangle {
        anchors.fill: parent
        radius: Config.radius(Config.rounding, height)
        color: Config.card
    }

    Frame {
        anchors.fill: parent
    }

    Avatar {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 18
    }

    Field {
        id: login

        property alias input: input

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 147

        focused: input.activeFocus

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11

            verticalAlignment: TextInput.AlignVCenter
            clip: true
            maximumLength: 64
            text: Auth.user
            color: Config.text
            selectionColor: Config.focus
            font.family: Config.fontFamily
            font.pixelSize: Config.textSize
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText | Qt.ImhPreferLowercase

            Accessible.name: "Login"

            onTextEdited: {
                Auth.user = input.text;
                Auth.failed = false;
                login.tap();
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Down) {
                    event.accepted = true;
                    password.forceActiveFocus();
                } else if (event.key === Qt.Key_Escape && Config.preview && input.text === "") {
                    Qt.quit();
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter

                opacity: input.text === "" ? 1 : 0
                text: "Login"
                color: Config.muted
                font: input.font

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animFast
                    }
                }
            }
        }
    }

    PasswordField {
        id: password

        anchors.left: login.left
        anchors.top: login.bottom
        anchors.topMargin: 17
        width: Config.fieldWidth - Config.submitWidth - 8

        onBack: login.input.forceActiveFocus()
    }

    Tile {
        anchors.right: login.right
        anchors.top: password.top
        width: Config.submitWidth
        height: Config.fieldHeight

        glyph: ""
        label: "Sign in"
        glyphSize: 16
        filled: true
        onClicked: {
            password.forceActiveFocus();
            Auth.submit();
        }
    }

    Text {
        anchors.left: login.left
        anchors.right: login.right
        anchors.top: password.bottom
        anchors.topMargin: 14

        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: Auth.failed ? Auth.message + " (" + Auth.attempts + ")" : Auth.message
        color: Auth.failed ? Config.fail : Config.muted
        font.family: Config.fontFamily
        font.pixelSize: Config.textSize - 2
        font.italic: true
    }
}
