pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Item {
    id: root

    readonly property int panelPadding: 16
    readonly property int panelWidth: 380

    // The access point the form below is filling in for, "" when there is no form: enterprise networks get the full form, everything else one password field, and a saved or open network neither.
    property string pendingName: ""
    property bool pendingEnterprise: false
    property bool advancedOpen: false

    readonly property var eapMethods: ["peap", "ttls"]
    readonly property var phaseMethods: ["mschapv2", "pap", "gtc"]

    property string eap: "peap"
    property string phase2: "mschapv2"

    // Typing into a popup needs the bar's layer surface focusable, and it only is while a form is up; the rest of the time the bar takes no keyboard, so clicking it does not pull focus off whatever was in front.
    onPendingNameChanged: UiState.keyboardCapture = root.pendingName !== ""

    function reset(): void {
        root.pendingName = "";
        root.pendingEnterprise = false;
        root.advancedOpen = false;
        root.eap = "peap";
        root.phase2 = "mschapv2";

        identityField.clear();
        anonymousField.clear();
        certificateField.clear();
        passwordField.clear();

        UiState.keyboardCapture = false;
    }

    function begin(point: var): void {
        // Already known to NetworkManager, so it has the secret and there is nothing to ask for.
        if (Network.isSaved(point.ssid)) {
            Network.connectSaved(point.ssid);
            return;
        }

        if (point.security === "") {
            Network.connectOpen(point.ssid);
            return;
        }

        root.reset();
        root.pendingName = point.ssid;
        root.pendingEnterprise = point.enterprise;

        if (point.enterprise)
            identityField.focusInput();
        else
            passwordField.focusInput();
    }

    function submit(): void {
        if (root.pendingName === "")
            return;

        if (root.pendingEnterprise)
            Network.connectEnterprise(root.pendingName, identityField.text.trim(), anonymousField.text.trim(), passwordField.text, root.eap, root.phase2, certificateField.text.trim());
        else
            Network.connectPersonal(root.pendingName, passwordField.text);

        // The password is gone from here the moment it has been handed over, and it was never written anywhere else.
        root.reset();
    }

    implicitWidth: root.panelWidth
    implicitHeight: content.implicitHeight + root.panelPadding * 2

    // A row of mutually exclusive words, small enough that a dropdown would be more machinery than the choice is worth.
    component ChoiceRow: Item {
        id: choiceRow

        property string label: ""
        property var options: []
        property string current: ""

        signal picked(string value)

        width: parent.width
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: choiceRow.label
            color: Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: choiceRow.options

                delegate: Rectangle {
                    id: choice

                    required property string modelData

                    readonly property bool selected: choiceRow.current === choice.modelData

                    width: choiceLabel.implicitWidth + 16
                    height: 22
                    radius: Theme.radius
                    color: {
                        if (choiceMouse.containsPress)
                            return Theme.fillPressed;
                        if (choiceMouse.containsMouse)
                            return Theme.fillHover;
                        return choice.selected ? Theme.accent : Theme.fillTrack;
                    }

                    Text {
                        id: choiceLabel
                        anchors.centerIn: parent
                        text: choice.modelData.toUpperCase()
                        color: choice.selected ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.monoFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: choiceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: choiceRow.picked(choice.modelData)
                    }
                }
            }
        }
    }

    Column {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.panelPadding

        spacing: 12

        Item {
            width: parent.width
            height: 28

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Network"
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSize
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                PanelButton {
                    glyph: Glyphs.rotate
                    available: Network.available && Network.wifiRadio && !Network.scanning
                    onActivated: Network.rescan()
                }

                PanelButton {
                    label: Network.wifiRadio ? "Wi-Fi on" : "Wi-Fi off"
                    accented: Network.wifiRadio
                    available: Network.available && !Network.busy
                    onActivated: Network.setWifiRadio(!Network.wifiRadio)
                }
            }
        }

        Card {
            width: parent.width
            height: 58
            visible: Network.connected

            IconText {
                id: activeGlyph

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14

                fillBarHeight: false
                text: Network.wired ? Glyphs.networkWired : Glyphs.wifi
                color: Theme.textPrimary
                font.pixelSize: 16
            }

            Text {
                id: activeName

                anchors.left: activeGlyph.right
                anchors.right: disconnectButton.left
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                anchors.top: parent.top
                anchors.topMargin: 12

                textFormat: Text.PlainText
                text: Network.wired ? Network.ethernetDevice.connection : Network.ssid
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightStrong
                elide: Text.ElideRight
            }

            Text {
                anchors.left: activeName.left
                anchors.right: activeName.right
                anchors.top: activeName.bottom
                anchors.topMargin: 2

                text: Network.wired ? "Wired connection" : "Connected, " + Network.signalStrength + "%"
                color: Theme.textMuted
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            PanelButton {
                id: disconnectButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 12

                label: "Disconnect"
                available: Network.wifiConnected && !Network.busy
                visible: Network.wifiConnected
                onActivated: Network.disconnect()
            }
        }

        PanelMessage {
            width: parent.width
            visible: !Network.available
            text: "nmcli was not found. The network module needs NetworkManager."
        }

        Item {
            width: parent.width
            height: Network.available && Network.wifiRadio ? Math.min(Math.max(pointList.contentHeight, 30), 200) : 0
            visible: height > 0
            clip: true

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }

            ListView {
                id: pointList

                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: Network.accessPoints
                }

                delegate: Rectangle {
                    id: pointRow

                    required property var modelData

                    readonly property bool saved: Network.isSaved(pointRow.modelData.ssid)

                    width: pointList.width
                    height: 32
                    radius: Theme.radius
                    color: {
                        if (pointRow.modelData.active)
                            return Theme.fillTrack;
                        return pointMouse.containsPress ? Theme.fillPressed : pointMouse.containsMouse ? Theme.fillHover : "transparent";
                    }

                    IconText {
                        id: pointLock

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10

                        fillBarHeight: false
                        visible: pointRow.modelData.security !== ""
                        text: Glyphs.lock
                        color: Theme.textMuted
                        font.pixelSize: 9
                    }

                    Text {
                        anchors.left: pointRow.modelData.security !== "" ? pointLock.right : parent.left
                        anchors.leftMargin: pointRow.modelData.security !== "" ? 8 : 10
                        anchors.right: pointStrength.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        textFormat: Text.PlainText
                        text: pointRow.modelData.ssid + (pointRow.saved ? "  ·  saved" : pointRow.modelData.enterprise ? "  ·  enterprise" : "")
                        color: pointRow.modelData.active ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    Text {
                        id: pointStrength

                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter

                        text: pointRow.modelData.signal + "%"
                        color: Theme.textMuted
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    MouseArea {
                        id: pointMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        enabled: !Network.busy

                        onClicked: event => {
                            if (event.button === Qt.RightButton) {
                                if (pointRow.saved)
                                    Network.forget(pointRow.modelData.ssid);
                                return;
                            }

                            root.begin(pointRow.modelData);
                        }
                    }
                }
            }
        }

        // The form: one password field for a personal network, the whole 802.1X set for an enterprise one, which is what eduroam is.
        Column {
            id: form

            width: parent.width
            spacing: 8
            visible: root.pendingName !== ""

            Text {
                width: parent.width
                text: (root.pendingEnterprise ? "Sign in to " : "Password for ") + root.pendingName
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightStrong
                elide: Text.ElideRight
            }

            TextField {
                id: identityField

                width: parent.width
                visible: root.pendingEnterprise
                label: "Identity"
                placeholder: "you@institution.edu"
                onAccepted: passwordField.focusInput()
            }

            TextField {
                id: passwordField

                width: parent.width
                label: "Password"
                secret: true
                onAccepted: root.submit()
            }

            Text {
                width: parent.width
                visible: root.pendingEnterprise
                text: root.advancedOpen ? "Hide advanced" : "Advanced"
                color: Theme.accent
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.advancedOpen = !root.advancedOpen
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.pendingEnterprise && root.advancedOpen

                ChoiceRow {
                    label: "EAP method"
                    options: root.eapMethods
                    current: root.eap
                    onPicked: value => root.eap = value
                }

                ChoiceRow {
                    label: "Phase 2"
                    options: root.phaseMethods
                    current: root.phase2
                    onPicked: value => root.phase2 = value
                }

                TextField {
                    id: anonymousField
                    width: parent.width
                    label: "Anonymous identity"
                    placeholder: "anonymous@institution.edu"
                }

                TextField {
                    id: certificateField
                    width: parent.width
                    label: "CA certificate"
                    placeholder: "/path/to/ca.pem, optional"
                }
            }

            Row {
                spacing: 6

                PanelButton {
                    label: "Connect"
                    accented: true
                    available: !Network.busy && passwordField.text !== "" && (!root.pendingEnterprise || identityField.text.trim() !== "")
                    onActivated: root.submit()
                }

                PanelButton {
                    label: "Cancel"
                    onActivated: root.reset()
                }
            }
        }

        PanelMessage {
            width: parent.width
            visible: Network.lastError !== ""
            warning: true
            text: Network.lastError
        }
    }
}
