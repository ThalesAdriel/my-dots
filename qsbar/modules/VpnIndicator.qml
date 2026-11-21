pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

BarButton {
    id: root

    highlighted: vpnPopup.shown

    onPrimaryClicked: vpnPopup.toggle()
    onSecondaryClicked: {
        if (Network.busy || !Network.available)
            return;
        if (Network.activeVpnNames.length > 0)
            Network.disconnectVpn(Network.activeVpnNames[0]);
        else if (Network.vpns.length > 0)
            Network.connectVpn(Network.vpns[0].name);
    }

    IconStack {
        IconText {
            anchors.centerIn: parent

            text: Glyphs.shield
            color: Network.vpnConnected ? Theme.accent : Theme.textMuted

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }
    }

    BarPopup {
        id: vpnPopup

        anchorItem: root
        alignRight: true
        warm: root.containsMouse

        readonly property bool wantsDetail: vpnPopup.prepared || vpnPopup.shown
        onWantsDetailChanged: Network.detailed = vpnPopup.wantsDetail

        Item {
            implicitWidth: 300
            implicitHeight: vpnCol.implicitHeight + 32

            Column {
                id: vpnCol

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                Text {
                    text: "VPN"
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSize
                    font.weight: Theme.fontWeightStrong
                }

                PanelMessage {
                    width: parent.width
                    visible: Network.vpns.length === 0
                    text: "No VPN or WireGuard profiles found in NetworkManager."
                }

                Repeater {
                    model: Network.vpns

                    delegate: Card {
                        id: itemCard

                        required property var modelData

                        width: vpnCol.width
                        height: 44

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: toggleBtn.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                fillBarHeight: false
                                text: Glyphs.shield
                                color: itemCard.modelData.active ? Theme.accent : Theme.textMuted
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 26
                                spacing: 1

                                Text {
                                    width: parent.width
                                    textFormat: Text.PlainText
                                    text: itemCard.modelData.name
                                    color: Theme.textPrimary
                                    font.family: Theme.sansFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: itemCard.modelData.active ? Theme.fontWeightStrong : Theme.fontWeightRegular
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    textFormat: Text.PlainText
                                    text: itemCard.modelData.active ? ("Connected · " + itemCard.modelData.type) : itemCard.modelData.type
                                    color: itemCard.modelData.active ? Theme.accent : Theme.textMuted
                                    font.family: Theme.sansFamily
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        PanelButton {
                            id: toggleBtn

                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter

                            label: itemCard.modelData.active ? "Disconnect" : "Connect"
                            accented: !itemCard.modelData.active
                            available: !Network.busy
                            onActivated: Network.toggleVpn(itemCard.modelData.name, itemCard.modelData.active)
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
    }

    BarTooltip {
        anchorItem: root
        shown: root.containsMouse && !vpnPopup.shown
        text: Network.vpnSummary
    }
}
