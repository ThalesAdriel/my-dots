import QtQuick
import "root:/config"

// A single line input in the shell's own idiom, built on TextInput rather than pulling in QtQuick.Controls, which brings a style along and would draw a field belonging to some other interface.
Item {
    id: root

    property string label: ""
    property string placeholder: ""
    property alias text: input.text
    property bool secret: false
    property bool revealed: false

    signal accepted

    // The inner TextInput is what actually takes the keyboard, so focus has to be handed down rather than left on the wrapper.
    function focusInput(): void {
        input.forceActiveFocus();
    }

    function clear(): void {
        input.text = "";
        root.revealed = false;
    }

    implicitHeight: (root.label !== "" ? fieldLabel.implicitHeight + 4 : 0) + 30
    implicitWidth: 200

    Text {
        id: fieldLabel

        anchors.left: parent.left
        anchors.top: parent.top

        visible: root.label !== ""
        text: root.label
        color: Theme.textSecondary
        font.family: Theme.sansFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    Rectangle {
        id: frame

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        height: 30
        radius: Theme.radius
        color: Theme.fillTrack
        border.width: 1
        border.color: input.activeFocus ? Theme.accent : Theme.cardBorder

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }

        TextInput {
            id: input

            anchors.left: parent.left
            anchors.right: revealButton.visible ? revealButton.left : parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 9
            anchors.rightMargin: 6

            clip: true
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            selectionColor: Theme.accent
            selectedTextColor: Theme.textPrimary
            selectByMouse: true
            activeFocusOnPress: true

            echoMode: root.secret && !root.revealed ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"

            onAccepted: root.accepted()

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                visible: input.text === ""
                text: root.placeholder
                color: Theme.textMuted
                font: input.font
            }
        }

        // Only ever a reveal, never a copy: the point of the field is that the value in it does not go anywhere the user did not send it.
        Rectangle {
            id: revealButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 4

            visible: root.secret && input.text !== ""
            width: 24
            height: 22
            radius: Theme.radius
            color: revealMouse.containsPress ? Theme.fillPressed : revealMouse.containsMouse ? Theme.fillHover : "transparent"

            IconText {
                anchors.centerIn: parent
                fillBarHeight: false
                text: root.revealed ? Glyphs.eyeSlash : Glyphs.eye
                color: Theme.textMuted
                font.pixelSize: 10
            }

            MouseArea {
                id: revealMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.revealed = !root.revealed
            }
        }
    }
}
