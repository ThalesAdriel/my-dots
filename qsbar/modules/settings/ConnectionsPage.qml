pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: pageRoot

    property string pendingWifi: ""
    property string wgImportPath: ""

    // Deduplicated Wi-Fi list: active first, then strongest signal.
    readonly property var wifiPoints: {
        const seen = {};
        const list = [];
        for (const pt of Network.accessPoints) {
            if (!pt || !pt.ssid || seen[pt.ssid])
                continue;
            seen[pt.ssid] = true;
            list.push(pt);
        }
        list.sort((a, b) => {
            if (a.active !== b.active)
                return a.active ? -1 : 1;
            return b.signal - a.signal;
        });
        return list;
    }

    // Paired & connected Bluetooth devices first.
    readonly property var btDevices: {
        const paired = Bluetooth.devices.filter(d => d.paired);
        const rest = Bluetooth.devices.filter(d => !d.paired);
        const rank = d => d.connected ? 0 : 1;
        return paired.slice().sort((a, b) => rank(a) - rank(b)).concat(rest);
    }

    function connectWifi(point: var): void {
        if (!point || !point.ssid)
            return;
        if (Network.isSaved(point.ssid)) {
            pageRoot.pendingWifi = "";
            Network.connectSaved(point.ssid);
            return;
        }
        if (point.security === "") {
            pageRoot.pendingWifi = "";
            Network.connectOpen(point.ssid);
            return;
        }
        pageRoot.pendingWifi = point.ssid;
        wifiPass.clear();
        Qt.callLater(wifiPass.focusInput);
    }

    Component.onCompleted: {
        Network.pageOpen = true;
        Network.detailed = true;
        Network.refresh();
        Bluetooth.pageOpen = true;
        Bluetooth.detailed = true;
        Bluetooth.refresh();
    }

    Component.onDestruction: {
        Network.detailed = false;
        Network.pageOpen = false;
        Bluetooth.stopScan();
        Bluetooth.detailed = false;
        Bluetooth.pageOpen = false;
    }

    spacing: 18

    // =========================================================================
    // Wi-Fi & Ethernet
    // =========================================================================
    Group {
        title: "Wi-Fi and Ethernet"

        PanelMessage {
            width: parent.width
            visible: !Network.available && !SettingsContext.searching
            warning: true
            text: "nmcli was not found. Wi-Fi and VPN controls require NetworkManager."
        }

        ToggleRow {
            label: "Show network icon in bar"
            checked: Settings.showNetwork
            onToggled: Settings.showNetwork = !Settings.showNetwork
        }

        ToggleRow {
            label: "Wi-Fi radio"
            applies: Network.available
            checked: Network.wifiRadio
            onToggled: Network.setWifiRadio(!Network.wifiRadio)
        }

        // Connection status summary row
        Item {
            id: netStatusRow

            readonly property bool hit: Network.available && SettingsContext.shows(netStatusRow, "Connection status ethernet wifi " + Network.summary)

            width: parent.width
            height: netStatusRow.hit ? 38 : 0
            visible: netStatusRow.hit

            Row {
                anchors.left: parent.left
                anchors.right: disconnectNetBtn.visible ? disconnectNetBtn.left : parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    fillBarHeight: false
                    text: Network.wired ? Glyphs.networkWired : Glyphs.wifi
                    color: Network.connected ? Theme.accent : Theme.textMuted
                    font.pixelSize: Theme.fontSizeSmall
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 26
                    textFormat: Text.PlainText
                    text: Network.summary
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            PanelButton {
                id: disconnectNetBtn

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Network.wifiConnected
                label: "Disconnect"
                available: !Network.busy
                onActivated: Network.disconnect()
            }
        }

        ButtonRow {
            label: Network.scanning ? "Scanning for Wi-Fi networks..." : "Scan for Wi-Fi networks"
            applies: Network.available && Network.wifiRadio
            enabledAction: !Network.scanning && !Network.busy
            onTriggered: Network.rescan()
        }

        // Inline password prompt for protected Wi-Fi networks
        Item {
            id: wifiPassBox

            readonly property bool hit: pageRoot.pendingWifi !== "" && !SettingsContext.searching

            width: parent.width
            height: wifiPassBox.hit ? wifiPassCol.implicitHeight : 0
            visible: wifiPassBox.hit

            Column {
                id: wifiPassCol

                width: parent.width
                spacing: 8

                TextField {
                    id: wifiPass

                    width: parent.width
                    label: "Password for " + pageRoot.pendingWifi
                    secret: true
                    onAccepted: {
                        if (wifiPass.text !== "") {
                            Network.connectPersonal(pageRoot.pendingWifi, wifiPass.text);
                            wifiPass.clear();
                            pageRoot.pendingWifi = "";
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    PanelButton {
                        label: "Cancel"
                        onActivated: {
                            wifiPass.clear();
                            pageRoot.pendingWifi = "";
                        }
                    }

                    PanelButton {
                        label: "Connect"
                        accented: true
                        available: !Network.busy && wifiPass.text !== ""
                        onActivated: {
                            Network.connectPersonal(pageRoot.pendingWifi, wifiPass.text);
                            wifiPass.clear();
                            pageRoot.pendingWifi = "";
                        }
                    }
                }
            }
        }

        Repeater {
            model: Network.available && Network.wifiRadio ? pageRoot.wifiPoints : []

            delegate: Item {
                id: apRow

                required property var modelData

                readonly property bool saved: Network.isSaved(apRow.modelData.ssid)
                readonly property bool hit: SettingsContext.shows(apRow, "wifi network " + apRow.modelData.ssid)

                width: parent.width
                height: apRow.hit ? 40 : 0
                visible: apRow.hit

                Row {
                    anchors.left: parent.left
                    anchors.right: apBtns.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        fillBarHeight: false
                        text: Glyphs.wifi
                        color: apRow.modelData.active ? Theme.accent : Theme.textMuted
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        spacing: 1

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: apRow.modelData.ssid
                            color: Theme.textPrimary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: apRow.modelData.active ? Theme.fontWeightStrong : Theme.fontWeightRegular
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: (apRow.modelData.active ? "Connected" : (apRow.saved ? "Saved" : (apRow.modelData.security || "Open"))) + " · " + apRow.modelData.signal + "%"
                            color: apRow.modelData.active ? Theme.accent : Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                            elide: Text.ElideRight
                        }
                    }
                }

                Row {
                    id: apBtns

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    PanelButton {
                        label: apRow.modelData.active ? "Disconnect" : "Connect"
                        accented: !apRow.modelData.active
                        available: !Network.busy
                        onActivated: {
                            if (apRow.modelData.active)
                                Network.disconnect();
                            else
                                pageRoot.connectWifi(apRow.modelData);
                        }
                    }

                    PanelButton {
                        visible: apRow.saved
                        glyph: Glyphs.xmark
                        available: !Network.busy
                        onActivated: Network.forget(apRow.modelData.ssid)
                    }
                }
            }
        }

        PanelMessage {
            width: parent.width
            visible: Network.lastError !== "" && !SettingsContext.searching
            warning: true
            text: Network.lastError
        }
    }

    // =========================================================================
    // VPN & WireGuard
    // =========================================================================
    Group {
        title: "VPN and WireGuard"

        ToggleRow {
            label: "Show VPN icon in bar (always shown when active)"
            checked: Settings.showVpn
            onToggled: Settings.showVpn = !Settings.showVpn
        }

        PanelMessage {
            width: parent.width
            visible: Network.available && Network.vpns.length === 0 && !SettingsContext.searching
            text: "No VPN or WireGuard profiles configured in NetworkManager yet."
        }

        Repeater {
            model: Network.available ? Network.vpns : []

            delegate: Item {
                id: vpnRow

                required property var modelData

                readonly property bool hit: SettingsContext.shows(vpnRow, "vpn wireguard " + vpnRow.modelData.name)

                width: parent.width
                height: vpnRow.hit ? 40 : 0
                visible: vpnRow.hit

                Row {
                    anchors.left: parent.left
                    anchors.right: vpnBtns.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        fillBarHeight: false
                        text: Glyphs.shield
                        color: vpnRow.modelData.active ? Theme.accent : Theme.textMuted
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        spacing: 1

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: vpnRow.modelData.name
                            color: Theme.textPrimary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: vpnRow.modelData.active ? Theme.fontWeightStrong : Theme.fontWeightRegular
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: vpnRow.modelData.active ? ("Connected · " + vpnRow.modelData.type) : vpnRow.modelData.type
                            color: vpnRow.modelData.active ? Theme.accent : Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                            elide: Text.ElideRight
                        }
                    }
                }

                Row {
                    id: vpnBtns

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    PanelButton {
                        label: vpnRow.modelData.active ? "Disconnect" : "Connect"
                        accented: !vpnRow.modelData.active
                        available: !Network.busy
                        onActivated: Network.toggleVpn(vpnRow.modelData.name, vpnRow.modelData.active)
                    }

                    PanelButton {
                        glyph: Glyphs.xmark
                        available: !Network.busy
                        onActivated: Network.forget(vpnRow.modelData.name)
                    }
                }
            }
        }

        FieldRow {
            label: "Import WireGuard (.conf)"
            value: pageRoot.wgImportPath
            placeholder: "~/Downloads/wg0.conf"
            browse: "file"
            nameFilters: ["*.conf"]
            applies: Network.available
            onCommitted: text => {
                if (text.trim() !== "") {
                    Network.importWireguard(text);
                    pageRoot.wgImportPath = "";
                }
            }
        }
    }

    // =========================================================================
    // Bluetooth
    // =========================================================================
    Group {
        title: "Bluetooth"

        PanelMessage {
            width: parent.width
            visible: !Bluetooth.available && !SettingsContext.searching
            warning: true
            text: "bluetoothctl was not found. Bluetooth controls require BlueZ."
        }

        ToggleRow {
            label: "Show Bluetooth icon in bar"
            checked: Settings.showBluetooth
            onToggled: Settings.showBluetooth = !Settings.showBluetooth
        }

        ToggleRow {
            label: "Bluetooth adapter"
            applies: Bluetooth.available
            checked: Bluetooth.powered
            onToggled: Bluetooth.setPowered(!Bluetooth.powered)
        }

        ButtonRow {
            label: Bluetooth.scanning ? "Stop scanning for Bluetooth devices" : "Scan for Bluetooth devices"
            applies: Bluetooth.available && Bluetooth.powered
            enabledAction: !Bluetooth.busy
            onTriggered: {
                if (Bluetooth.scanning)
                    Bluetooth.stopScan();
                else
                    Bluetooth.scan();
            }
        }

        PanelMessage {
            width: parent.width
            visible: Bluetooth.available && Bluetooth.powered && pageRoot.btDevices.length === 0 && !SettingsContext.searching
            text: "No paired or nearby Bluetooth devices found."
        }

        Repeater {
            model: Bluetooth.available && Bluetooth.powered ? pageRoot.btDevices : []

            delegate: Item {
                id: btRow

                required property var modelData

                readonly property bool hit: SettingsContext.shows(btRow, "bluetooth device " + btRow.modelData.name + " " + btRow.modelData.address)

                width: parent.width
                height: btRow.hit ? 40 : 0
                visible: btRow.hit

                Row {
                    anchors.left: parent.left
                    anchors.right: btBtns.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        fillBarHeight: false
                        text: Glyphs.bluetooth
                        color: btRow.modelData.connected ? Theme.accent : Theme.textMuted
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        spacing: 1

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: btRow.modelData.name || btRow.modelData.address
                            color: Theme.textPrimary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: btRow.modelData.connected ? Theme.fontWeightStrong : Theme.fontWeightRegular
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: btRow.modelData.connected ? "Connected" : (btRow.modelData.paired ? "Paired" : btRow.modelData.address)
                            color: btRow.modelData.connected ? Theme.accent : Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                            elide: Text.ElideRight
                        }
                    }
                }

                Row {
                    id: btBtns

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    PanelButton {
                        label: btRow.modelData.connected ? "Disconnect" : (btRow.modelData.paired ? "Connect" : "Pair")
                        accented: !btRow.modelData.connected
                        available: !Bluetooth.busy
                        onActivated: {
                            if (btRow.modelData.connected)
                                Bluetooth.disconnectDevice(btRow.modelData.address);
                            else if (btRow.modelData.paired)
                                Bluetooth.connectDevice(btRow.modelData.address);
                            else
                                Bluetooth.pairDevice(btRow.modelData.address);
                        }
                    }

                    PanelButton {
                        visible: btRow.modelData.paired
                        glyph: Glyphs.xmark
                        available: !Bluetooth.busy
                        onActivated: Bluetooth.forgetDevice(btRow.modelData.address)
                    }
                }
            }
        }

        PanelMessage {
            width: parent.width
            visible: Bluetooth.lastError !== "" && !SettingsContext.searching
            warning: true
            text: Bluetooth.lastError
        }
    }
}
