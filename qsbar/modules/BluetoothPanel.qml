pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Item {
    id: root

    readonly property int panelPadding: 16
    readonly property int panelWidth: 340

    // Paired devices first, then whatever the scan turned up, with anything already connected sorted to the top of its own group.
    readonly property var listed: {
        const paired = Bluetooth.devices.filter(device => device.paired);
        const rest = Bluetooth.devices.filter(device => !device.paired);
        const rank = device => device.connected ? 0 : 1;
        return paired.slice().sort((left, right) => rank(left) - rank(right)).concat(rest);
    }

    implicitWidth: root.panelWidth
    implicitHeight: content.implicitHeight + root.panelPadding * 2

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
                text: "Bluetooth"
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSize
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                PanelButton {
                    label: Bluetooth.scanning ? "Scanning" : "Scan"
                    available: Bluetooth.available && Bluetooth.powered && !Bluetooth.scanning
                    onActivated: Bluetooth.scan()
                }

                PanelButton {
                    label: Bluetooth.powered ? "On" : "Off"
                    accented: Bluetooth.powered
                    available: Bluetooth.available && !Bluetooth.busy
                    onActivated: Bluetooth.setPowered(!Bluetooth.powered)
                }
            }
        }

        PanelMessage {
            width: parent.width
            visible: !Bluetooth.available
            text: "bluetoothctl was not found. The bluetooth module needs BlueZ."
        }

        PanelMessage {
            width: parent.width
            visible: Bluetooth.available && Bluetooth.powered && root.listed.length === 0
            text: "Nothing paired yet. Scan to find devices nearby."
        }

        Item {
            width: parent.width
            height: Bluetooth.powered && root.listed.length > 0 ? Math.min(deviceList.contentHeight, 240) : 0
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
                id: deviceList

                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: root.listed
                }

                delegate: Rectangle {
                    id: deviceRow

                    required property var modelData

                    width: deviceList.width
                    height: 34
                    radius: Theme.radius
                    color: {
                        if (deviceRow.modelData.connected)
                            return Theme.fillTrack;
                        return deviceMouse.containsPress ? Theme.fillPressed : deviceMouse.containsMouse ? Theme.fillHover : "transparent";
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: deviceState.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        textFormat: Text.PlainText
                        text: deviceRow.modelData.name
                        color: deviceRow.modelData.connected ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    Text {
                        id: deviceState

                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter

                        text: {
                            if (deviceRow.modelData.connected)
                                return "connected";
                            return deviceRow.modelData.paired ? "paired" : "new";
                        }
                        color: Theme.textMuted
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    // Left click is the one thing the row does; right click on a paired device removes it, the same gesture the network list uses to forget a saved network.
                    MouseArea {
                        id: deviceMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        enabled: !Bluetooth.busy

                        onClicked: event => {
                            const device = deviceRow.modelData;

                            if (event.button === Qt.RightButton) {
                                if (device.paired)
                                    Bluetooth.forgetDevice(device.address);
                                return;
                            }

                            if (device.connected)
                                Bluetooth.disconnectDevice(device.address);
                            else if (device.paired)
                                Bluetooth.connectDevice(device.address);
                            else
                                Bluetooth.pairDevice(device.address);
                        }
                    }
                }
            }
        }

        PanelMessage {
            width: parent.width
            visible: Bluetooth.lastError !== ""
            warning: true
            text: Bluetooth.lastError
        }
    }
}
