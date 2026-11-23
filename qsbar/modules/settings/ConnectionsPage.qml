pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: pageRoot

    property string pendingWifi: ""
    property bool pendingEnterprise: false
    property string eapMethod: "peap"
    property string phase2Method: "mschapv2"
    property bool hiddenOpen: false
    property bool customDnsOpen: false
    property bool manualIpv4Open: false
    property bool hotspotOpen: false
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

    function resetWifiForm(): void {
        pageRoot.pendingWifi = "";
        pageRoot.pendingEnterprise = false;
        wifiPass.clear();
        wifiIdentity.clear();
        wifiAnonymous.clear();
        wifiCaCert.clear();
    }

    function connectWifi(point: var): void {
        if (!point || !point.ssid)
            return;
        if (Network.isSaved(point.ssid)) {
            pageRoot.resetWifiForm();
            Network.connectSaved(point.ssid);
            return;
        }
        if (point.security === "") {
            pageRoot.resetWifiForm();
            Network.connectOpen(point.ssid);
            return;
        }
        pageRoot.resetWifiForm();
        pageRoot.pendingWifi = point.ssid;
        pageRoot.pendingEnterprise = point.enterprise === true;
        Qt.callLater(pageRoot.pendingEnterprise ? wifiIdentity.focusInput : wifiPass.focusInput);
    }

    function submitWifiForm(): void {
        if (pageRoot.pendingWifi === "" || wifiPass.text === "")
            return;
        if (pageRoot.pendingEnterprise) {
            if (wifiIdentity.text.trim() === "")
                return;
            Network.connectEnterprise(pageRoot.pendingWifi, wifiIdentity.text.trim(), wifiAnonymous.text.trim(), wifiPass.text, pageRoot.eapMethod, pageRoot.phase2Method, wifiCaCert.text.trim());
        } else {
            Network.connectPersonal(pageRoot.pendingWifi, wifiPass.text);
        }
        pageRoot.resetWifiForm();
    }

    Component.onCompleted: {
        Network.pageOpen = true;
        Network.refresh();
        Bluetooth.pageOpen = true;
        Bluetooth.refresh();
    }

    Component.onDestruction: {
        Network.clearPassword();
        Network.pageOpen = false;
        Bluetooth.stopScan();
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

        // Ethernet interfaces (connect / disconnect wired network cards such as enp34s0)
        Repeater {
            model: Network.available ? Network.ethernetDevices : []

            delegate: Item {
                id: ethDevRow

                required property var modelData

                readonly property bool isConnected: ethDevRow.modelData.state === "connected"
                readonly property bool isUnavailable: ethDevRow.modelData.state === "unavailable" || ethDevRow.modelData.state === "unmanaged"
                readonly property bool hit: SettingsContext.shows(ethDevRow, "ethernet wired cable lan " + ethDevRow.modelData.device + " " + ethDevRow.modelData.connection + " " + ethDevRow.modelData.state)

                width: parent.width
                height: ethDevRow.hit ? 40 : 0
                visible: ethDevRow.hit

                Row {
                    anchors.left: parent.left
                    anchors.right: ethDevBtn.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        fillBarHeight: false
                        text: Glyphs.networkWired
                        color: ethDevRow.isConnected ? Theme.accent : Theme.textMuted
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 26
                        spacing: 1

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: "Wired (" + ethDevRow.modelData.device + ")" + (ethDevRow.modelData.connection && ethDevRow.modelData.connection !== "--" ? " · " + ethDevRow.modelData.connection : "")
                            color: Theme.textPrimary
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: ethDevRow.isConnected ? Theme.fontWeightStrong : Theme.fontWeightRegular
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: ethDevRow.isConnected ? "Connected" : (ethDevRow.isUnavailable ? "Cable unplugged (" + ethDevRow.modelData.state + ")" : "Disconnected")
                            color: ethDevRow.isConnected ? Theme.accent : Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                            elide: Text.ElideRight
                        }
                    }
                }

                PanelButton {
                    id: ethDevBtn

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    label: ethDevRow.isConnected ? "Disconnect" : "Connect"
                    accented: !ethDevRow.isConnected && !ethDevRow.isUnavailable
                    available: !Network.busy && !ethDevRow.isUnavailable
                    onActivated: Network.toggleEthernet(ethDevRow.modelData.device, ethDevRow.isConnected)
                }
            }
        }

        ToggleRow {
            label: "Wi-Fi radio"
            applies: Network.available && Network.wifiDevice !== null
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
                visible: Network.wifiConnected || (Network.anyEthernetDevice !== null && !Network.wired && Network.anyEthernetDevice.state === "disconnected")
                label: Network.wifiConnected ? "Disconnect" : "Connect Wired"
                accented: !Network.wifiConnected
                available: !Network.busy
                onActivated: {
                    if (Network.wifiConnected)
                        Network.disconnect();
                    else if (Network.anyEthernetDevice)
                        Network.connectEthernet(Network.anyEthernetDevice.device);
                }
            }
        }

        // Active IPv4 / IPv6 / Gateway / DNS details
        Item {
            id: ipInfoRow

            readonly property bool hasIp: Network.available && Network.connected && (Network.ipAddress !== "" || Network.ipv6Address !== "")
            readonly property bool hit: ipInfoRow.hasIp && SettingsContext.shows(ipInfoRow, "ip ipv4 ipv6 address gateway dns " + Network.ipAddress + " " + Network.ipv6Address + " " + Network.gateway + " " + Network.dnsServers + " " + Network.ipv6Dns)

            width: parent.width
            height: ipInfoRow.hit ? ipInfoCol.implicitHeight : 0
            visible: ipInfoRow.hit

            Column {
                id: ipInfoCol

                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    visible: Network.ipAddress !== ""
                    textFormat: Text.PlainText
                    text: "IPv4: " + Network.ipAddress + (Network.gateway !== "" ? "   ·   Gateway: " + Network.gateway : "")
                    color: Theme.textSecondary
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: Network.dnsServers !== ""
                    textFormat: Text.PlainText
                    text: "DNS4: " + Network.dnsServers
                    color: Theme.textMuted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: Network.ipv6Address !== ""
                    textFormat: Text.PlainText
                    text: "IPv6: " + Network.ipv6Address + (Network.ipv6Gateway !== "" ? "   ·   GW: " + Network.ipv6Gateway : "")
                    color: Theme.textSecondary
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: Network.ipv6Dns !== ""
                    textFormat: Text.PlainText
                    text: "DNS6: " + Network.ipv6Dns
                    color: Theme.textMuted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSizeSmall - 1
                    elide: Text.ElideRight
                }

                // Quick actions: copy IPs and reveal saved Wi-Fi password
                Row {
                    spacing: 6
                    topPadding: 4

                    PanelButton {
                        visible: Network.ipAddress !== ""
                        label: "Copy IPv4"
                        onActivated: Network.copyText(Network.ipAddress.split("/")[0])
                    }

                    PanelButton {
                        visible: Network.ipv6Address !== ""
                        label: "Copy IPv6"
                        onActivated: Network.copyText(Network.ipv6Address.split("/")[0])
                    }

                    PanelButton {
                        visible: Network.wifiConnected && Network.activeConnection !== ""
                        label: Network.revealedPassword !== "" ? "Hide password" : "Show Wi-Fi password"
                        onActivated: {
                            if (Network.revealedPassword !== "")
                                Network.clearPassword();
                            else
                                Network.revealWifiPassword();
                        }
                    }
                }

                Row {
                    visible: Network.revealedPassword !== ""
                    spacing: 8
                    topPadding: 4

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: "Password: " + Network.revealedPassword
                        color: Theme.accent
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall - 1
                    }

                    PanelButton {
                        label: "Copy"
                        onActivated: Network.copyText(Network.revealedPassword)
                    }
                }
            }
        }

        ToggleRow {
            label: "Connect automatically"
            applies: Network.available && Network.connected && Network.activeConnection !== ""
            checked: Network.autoconnect
            onToggled: Network.setAutoconnect(!Network.autoconnect)
        }

        ChoiceRow {
            label: "Wi-Fi MAC privacy"
            applies: Network.available && Network.wifiConnected && Network.activeConnection !== ""
            options: [
                { value: "permanent", label: "Permanent" },
                { value: "random", label: "Random" },
                { value: "stable", label: "Stable" }
            ]
            current: Network.macMode
            onPicked: value => Network.setMacMode(value)
        }

        ChoiceRow {
            label: "DNS"
            applies: Network.available && Network.connected && Network.activeConnection !== ""
            options: [
                { value: "auto", label: "Auto" },
                { value: "cloudflare", label: "Cloudflare" },
                { value: "google", label: "Google" },
                { value: "quad9", label: "Quad9" },
                { value: "custom", label: "Custom" }
            ]
            current: pageRoot.customDnsOpen ? "custom" : Network.dnsPreset
            onPicked: value => {
                if (value === "custom") {
                    pageRoot.customDnsOpen = true;
                    customDnsField.text = Network.customDns;
                    Qt.callLater(customDnsField.focusInput);
                } else {
                    pageRoot.customDnsOpen = false;
                    Network.setDnsPreset(value, "");
                }
            }
        }

        Item {
            id: customDnsBox

            readonly property bool hit: pageRoot.customDnsOpen && Network.available && Network.connected && !SettingsContext.searching

            width: parent.width
            height: customDnsBox.hit ? customDnsCol.implicitHeight : 0
            visible: customDnsBox.hit

            Column {
                id: customDnsCol

                width: parent.width
                spacing: 8

                TextField {
                    id: customDnsField

                    width: parent.width
                    label: "Custom DNS servers (space or comma separated)"
                    placeholder: "1.1.1.1 9.9.9.9"
                    onAccepted: {
                        Network.setDnsPreset("custom", customDnsField.text);
                        pageRoot.customDnsOpen = false;
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    PanelButton {
                        label: "Cancel"
                        onActivated: pageRoot.customDnsOpen = false
                    }

                    PanelButton {
                        label: "Apply DNS"
                        accented: true
                        available: !Network.busy && customDnsField.text.trim() !== ""
                        onActivated: {
                            Network.setDnsPreset("custom", customDnsField.text);
                            pageRoot.customDnsOpen = false;
                        }
                    }
                }
            }
        }

        ChoiceRow {
            label: "IPv4"
            applies: Network.available && Network.connected && Network.activeConnection !== ""
            options: [
                { value: "auto", label: "Auto (DHCP)" },
                { value: "manual", label: "Manual" }
            ]
            current: pageRoot.manualIpv4Open ? "manual" : (Network.ipv4Method === "manual" ? "manual" : "auto")
            onPicked: value => {
                if (value === "manual") {
                    pageRoot.manualIpv4Open = true;
                    manualIpField.text = Network.ipAddress;
                    manualGwField.text = Network.gateway;
                    Qt.callLater(manualIpField.focusInput);
                } else {
                    pageRoot.manualIpv4Open = false;
                    Network.setIpv4Auto();
                }
            }
        }

        Item {
            id: manualIpv4Box

            readonly property bool hit: pageRoot.manualIpv4Open && Network.available && Network.connected && !SettingsContext.searching

            width: parent.width
            height: manualIpv4Box.hit ? manualIpv4Col.implicitHeight : 0
            visible: manualIpv4Box.hit

            Column {
                id: manualIpv4Col

                width: parent.width
                spacing: 8

                TextField {
                    id: manualIpField

                    width: parent.width
                    label: "IPv4 Address (CIDR)"
                    placeholder: "192.168.1.50/24"
                    onAccepted: manualGwField.focusInput()
                }

                TextField {
                    id: manualGwField

                    width: parent.width
                    label: "Gateway (optional)"
                    placeholder: "192.168.1.1"
                    onAccepted: {
                        Network.setIpv4Manual(manualIpField.text, manualGwField.text);
                        pageRoot.manualIpv4Open = false;
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    PanelButton {
                        label: "Cancel"
                        onActivated: pageRoot.manualIpv4Open = false
                    }

                    PanelButton {
                        label: "Apply IPv4"
                        accented: true
                        available: !Network.busy && manualIpField.text.trim() !== ""
                        onActivated: {
                            Network.setIpv4Manual(manualIpField.text, manualGwField.text);
                            pageRoot.manualIpv4Open = false;
                        }
                    }
                }
            }
        }

        ChoiceRow {
            label: "IPv6"
            applies: Network.available && Network.connected && Network.activeConnection !== ""
            options: [
                { value: "auto", label: "Auto" },
                { value: "disabled", label: "Disabled" },
                { value: "ignore", label: "Ignore" },
                { value: "link-local", label: "Link-local" }
            ]
            current: Network.ipv6Method
            onPicked: value => Network.setIpv6Method(value)
        }

        ButtonRow {
            label: Network.hotspotActive ? "Stop Wi-Fi hotspot" : (pageRoot.hotspotOpen ? "Hide Wi-Fi hotspot form" : "Create Wi-Fi hotspot")
            applies: Network.available && Network.wifiDevice !== null
            enabledAction: !Network.busy
            onTriggered: {
                if (Network.hotspotActive)
                    Network.stopHotspot();
                else
                    pageRoot.hotspotOpen = !pageRoot.hotspotOpen;
            }
        }

        Item {
            id: hotspotBox

            readonly property bool hit: pageRoot.hotspotOpen && !Network.hotspotActive && Network.available && Network.wifiDevice !== null && !SettingsContext.searching

            width: parent.width
            height: hotspotBox.hit ? hotspotCol.implicitHeight : 0
            visible: hotspotBox.hit

            Column {
                id: hotspotCol

                width: parent.width
                spacing: 8

                TextField {
                    id: hotspotSsid

                    width: parent.width
                    label: "Hotspot SSID"
                    placeholder: "MyHotspot"
                    onAccepted: hotspotPass.focusInput()
                }

                TextField {
                    id: hotspotPass

                    width: parent.width
                    label: "Hotspot password (min 8 chars, empty for open)"
                    secret: true
                    onAccepted: {
                        if (hotspotSsid.text.trim() !== "") {
                            Network.startHotspot(hotspotSsid.text, hotspotPass.text);
                            hotspotPass.clear();
                            pageRoot.hotspotOpen = false;
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    PanelButton {
                        label: "Cancel"
                        onActivated: {
                            hotspotPass.clear();
                            pageRoot.hotspotOpen = false;
                        }
                    }

                    PanelButton {
                        label: "Start Hotspot"
                        accented: true
                        available: !Network.busy && hotspotSsid.text.trim() !== "" && (hotspotPass.text === "" || hotspotPass.text.length >= 8)
                        onActivated: {
                            Network.startHotspot(hotspotSsid.text, hotspotPass.text);
                            hotspotPass.clear();
                            pageRoot.hotspotOpen = false;
                        }
                    }
                }
            }
        }

        ButtonRow {
            label: Network.scanning ? "Scanning for Wi-Fi networks..." : "Scan for Wi-Fi networks"
            applies: Network.available && Network.wifiRadio
            enabledAction: !Network.scanning && !Network.busy
            onTriggered: Network.rescan()
        }

        // Inline password / WPA-Enterprise prompt for protected Wi-Fi networks
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
                    id: wifiIdentity

                    width: parent.width
                    visible: pageRoot.pendingEnterprise
                    label: "Identity (" + pageRoot.pendingWifi + ")"
                    placeholder: "you@institution.edu"
                    onAccepted: wifiPass.focusInput()
                }

                TextField {
                    id: wifiPass

                    width: parent.width
                    label: "Password for " + pageRoot.pendingWifi
                    secret: true
                    onAccepted: pageRoot.submitWifiForm()
                }

                ChoiceRow {
                    label: "EAP method"
                    applies: pageRoot.pendingEnterprise
                    options: [
                        { value: "peap", label: "PEAP" },
                        { value: "ttls", label: "TTLS" }
                    ]
                    current: pageRoot.eapMethod
                    onPicked: value => pageRoot.eapMethod = value
                }

                ChoiceRow {
                    label: "Phase 2"
                    applies: pageRoot.pendingEnterprise
                    options: [
                        { value: "mschapv2", label: "MSCHAPv2" },
                        { value: "pap", label: "PAP" },
                        { value: "gtc", label: "GTC" }
                    ]
                    current: pageRoot.phase2Method
                    onPicked: value => pageRoot.phase2Method = value
                }

                TextField {
                    id: wifiAnonymous

                    width: parent.width
                    visible: pageRoot.pendingEnterprise
                    label: "Anonymous identity (optional)"
                    placeholder: "anonymous@institution.edu"
                }

                TextField {
                    id: wifiCaCert

                    width: parent.width
                    visible: pageRoot.pendingEnterprise
                    label: "CA certificate (optional)"
                    placeholder: "/path/to/ca.pem"
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    PanelButton {
                        label: "Cancel"
                        onActivated: pageRoot.resetWifiForm()
                    }

                    PanelButton {
                        label: "Connect"
                        accented: true
                        available: !Network.busy && wifiPass.text !== "" && (!pageRoot.pendingEnterprise || wifiIdentity.text.trim() !== "")
                        onActivated: pageRoot.submitWifiForm()
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

        ButtonRow {
            label: pageRoot.hiddenOpen ? "Hide hidden network form" : "Connect to a hidden Wi-Fi network"
            applies: Network.available && Network.wifiRadio
            onTriggered: pageRoot.hiddenOpen = !pageRoot.hiddenOpen
        }

        Item {
            id: hiddenBox

            readonly property bool hit: pageRoot.hiddenOpen && Network.available && Network.wifiRadio && !SettingsContext.searching

            width: parent.width
            height: hiddenBox.hit ? hiddenCol.implicitHeight : 0
            visible: hiddenBox.hit

            Column {
                id: hiddenCol

                width: parent.width
                spacing: 8

                TextField {
                    id: hiddenSsid

                    width: parent.width
                    label: "Hidden network SSID"
                    placeholder: "Network name"
                    onAccepted: hiddenPass.focusInput()
                }

                TextField {
                    id: hiddenPass

                    width: parent.width
                    label: "Password (leave empty if open)"
                    secret: true
                    onAccepted: {
                        if (hiddenSsid.text.trim() !== "") {
                            Network.connectHidden(hiddenSsid.text.trim(), hiddenPass.text);
                            hiddenSsid.clear();
                            hiddenPass.clear();
                            pageRoot.hiddenOpen = false;
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    PanelButton {
                        label: "Cancel"
                        onActivated: {
                            hiddenSsid.clear();
                            hiddenPass.clear();
                            pageRoot.hiddenOpen = false;
                        }
                    }

                    PanelButton {
                        label: "Connect"
                        accented: true
                        available: !Network.busy && hiddenSsid.text.trim() !== ""
                        onActivated: {
                            Network.connectHidden(hiddenSsid.text.trim(), hiddenPass.text);
                            hiddenSsid.clear();
                            hiddenPass.clear();
                            pageRoot.hiddenOpen = false;
                        }
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
    // Saved Wi-Fi profiles (including out-of-range networks)
    // =========================================================================
    Group {
        title: "Saved Wi-Fi networks"

        PanelMessage {
            width: parent.width
            visible: Network.available && Network.savedNames.length === 0 && !SettingsContext.searching
            text: "No saved Wi-Fi profiles yet."
        }

        Repeater {
            model: Network.available ? Network.savedNames : []

            delegate: Item {
                id: savedRow

                required property string modelData

                readonly property bool isCurrent: Network.wifiConnected && Network.ssid === savedRow.modelData
                readonly property bool hit: SettingsContext.shows(savedRow, "saved wifi profile " + savedRow.modelData)

                width: parent.width
                height: savedRow.hit ? 34 : 0
                visible: savedRow.hit

                Text {
                    anchors.left: parent.left
                    anchors.right: savedBtns.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: savedRow.isCurrent ? (savedRow.modelData + "  (connected)") : savedRow.modelData
                    color: savedRow.isCurrent ? Theme.accent : Theme.textPrimary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                Row {
                    id: savedBtns

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    PanelButton {
                        label: savedRow.isCurrent ? "Disconnect" : "Connect"
                        available: !Network.busy && Network.wifiRadio
                        onActivated: {
                            if (savedRow.isCurrent)
                                Network.disconnect();
                            else
                                Network.connectSaved(savedRow.modelData);
                        }
                    }

                    PanelButton {
                        glyph: Glyphs.xmark
                        available: !Network.busy
                        onActivated: Network.forget(savedRow.modelData)
                    }
                }
            }
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

        ToggleRow {
            label: "Auto-connect VPN on startup"
            applies: Network.available
            checked: Settings.vpnAutoconnect
            onToggled: Network.setVpnAutoconnectGlobal(!Settings.vpnAutoconnect)
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
                            text: (vpnRow.modelData.active ? ("Connected · " + vpnRow.modelData.type) : vpnRow.modelData.type) + (vpnRow.modelData.autoconnect ? " · auto-connect on" : " · auto-connect off")
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
                        label: vpnRow.modelData.autoconnect ? "Auto: On" : "Auto: Off"
                        accented: vpnRow.modelData.autoconnect === true
                        available: !Network.busy
                        onActivated: Network.setVpnProfileAutoconnect(vpnRow.modelData.name, !vpnRow.modelData.autoconnect)
                    }

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
