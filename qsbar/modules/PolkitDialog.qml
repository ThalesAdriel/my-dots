pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "root:/config"
import "root:/components"

// The polkit authentication agent, inside the shell rather than beside it. hyprpolkitagent was installed and never started, and the chain hyprland.start reached for instead was not installed at all, so anything that asked for authorisation got no prompt and simply failed.
Scope {
    id: scope

    readonly property var flow: agent.flow

    // A flow that has completed is one whose window should already be going away; isActive alone leaves the card up for a frame holding a dead flow.
    readonly property bool active: agent.isActive && scope.flow !== null && !scope.flow.isCompleted

    function submit(): void {
        if (scope.flow && scope.flow.isResponseRequired)
            scope.flow.submit(field.text);
    }

    function cancel(): void {
        if (scope.flow)
            scope.flow.cancelAuthenticationRequest();
    }

    // ponytail: whatever polkit preselected in flow.selectedIdentity is who authenticates. On a machine where the action admits more than one identity, add a picker over flow.identities above the field.
    PolkitAgent {
        id: agent

        // A new request reuses the same window, so the field has to be emptied here rather than on the way out: the previous password must not be sitting there waiting to be submitted to something else.
        onAuthenticationRequestStarted: field.clear()
    }

    // Cleared on the way out too, so a password does not outlive the prompt it was typed into.
    onActiveChanged: {
        if (scope.active)
            Qt.callLater(field.focusInput);
        else
            field.clear();
    }

    PanelWindow {
        id: window

        visible: scope.active

        WlrLayershell.namespace: Theme.panelLayerNamespace
        WlrLayershell.layer: WlrLayer.Overlay

        // Exclusive while it is up: a password prompt that the window underneath can keep typing into is not a password prompt.
        WlrLayershell.keyboardFocus: scope.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusiveZone: -1
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.45
        }

        // Swallows everything that misses the card: clicking the desktop must not reach the desktop while this is waiting.
        MouseArea {
            anchors.fill: parent
        }

        Item {
            anchors.fill: parent
            focus: true

            // The field holds the focus, and Escape is the one key it does not take, so it arrives here on the way up.
            Keys.onEscapePressed: scope.cancel()

            Card {
                anchors.centerIn: parent

                width: 380
                implicitHeight: column.implicitHeight + 32

                Column {
                    id: column

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16

                    spacing: 12

                    Row {
                        spacing: 10

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            fillBarHeight: false
                            text: Glyphs.lock
                            color: Theme.accent
                            font.pixelSize: 16
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Authentication required"
                            color: Theme.textPrimary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Theme.fontWeightStrong
                        }
                    }

                    // Whatever the action declared about itself. It is the caller's string, so it is drawn as text and never as markup.
                    Text {
                        width: parent.width
                        visible: text !== ""
                        textFormat: Text.PlainText
                        text: scope.flow ? scope.flow.message : ""
                        color: Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    TextField {
                        id: field

                        width: parent.width

                        // pam decides what it is asking for and whether the answer may be shown; this is not always a password.
                        label: scope.flow && scope.flow.inputPrompt !== "" ? scope.flow.inputPrompt : "Password"
                        secret: !(scope.flow && scope.flow.responseVisible)
                        visible: scope.flow !== null && scope.flow.isResponseRequired

                        onAccepted: scope.submit()
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        textFormat: Text.PlainText
                        text: scope.flow ? scope.flow.supplementaryMessage : ""
                        color: scope.flow && scope.flow.supplementaryIsError ? Theme.urgent : Theme.textMuted
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        PanelButton {
                            label: "Cancel"
                            onActivated: scope.cancel()
                        }

                        PanelButton {
                            label: "Authenticate"
                            accented: true
                            available: scope.flow !== null && scope.flow.isResponseRequired
                            onActivated: scope.submit()
                        }
                    }
                }
            }
        }
    }
}
