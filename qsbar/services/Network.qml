pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// NetworkManager through nmcli, since Quickshell has no network service.
Singleton {
    id: root

    // Nothing runs until the network/VPN bar module or Settings page is open.
    property bool pageOpen: false
    readonly property bool enabled: Settings.showNetwork || Settings.showVpn || root.pageOpen

    // The panel or Settings page needs the access point list, saved profiles and VPN list; the bar needs none of them.
    property bool networkPopupDetailed: false
    property bool vpnPopupDetailed: false
    readonly property bool detailed: root.networkPopupDetailed || root.vpnPopupDetailed || root.pageOpen

    readonly property int idleInterval: 6000
    readonly property int activeInterval: 2500

    // What the poll drops to once `nmcli monitor` is carrying the state changes.
    readonly property int watchedInterval: 60000

    property bool available: true
    property bool wifiRadio: true
    property bool scanning: false
    property bool busy: false
    property string lastError: ""

    // [{ device, type, state, connection }].
    property var devices: []
    // [{ ssid, signal, security, enterprise, active }].
    property var accessPoints: []
    property var savedNames: []
    // [{ name, type, active, device }] for Ethernet profiles.
    property var ethernetProfiles: []
    // [{ name, type, active, autoconnect }] for WireGuard and NetworkManager VPN profiles.
    property var vpns: []
    property var activeVpnNames: []
    property bool startupPolicyApplied: false

    // Active interface IPv4/IPv6 info & connection settings, only populated during full reads (Settings / open panel).
    property string activeConnection: ""
    property string ipAddress: ""
    property string gateway: ""
    property string dnsServers: ""
    property string ipv6Address: ""
    property string ipv6Gateway: ""
    property string ipv6Dns: ""
    property string ipv4Method: "auto"
    property string ipv6Method: "auto"
    property string dnsPreset: "auto"
    property string customDns: ""
    property bool autoconnect: true
    property string macMode: "permanent"
    property bool hotspotActive: false
    property string revealedPassword: ""

    readonly property var activeVpns: {
        const list = [];
        for (const name of root.activeVpnNames) {
            list.push(name);
        }
        return list;
    }
    readonly property bool vpnConnected: root.activeVpnNames.length > 0
    readonly property string vpnSummary: {
        if (!root.available)
            return "NetworkManager not found";
        if (root.activeVpnNames.length === 1)
            return "VPN: " + root.activeVpnNames[0];
        if (root.activeVpnNames.length > 1)
            return "VPN: " + root.activeVpnNames.length + " active";
        return "VPN disconnected";
    }

    readonly property var wifiDevice: {
        for (const device of root.devices) {
            if (device.type === "wifi")
                return device;
        }
        return null;
    }

    readonly property var ethernetDevices: {
        const list = [];
        for (const device of root.devices) {
            if (device.type === "ethernet" || device.type === "bridge")
                list.push(device);
        }
        return list;
    }

    readonly property var anyEthernetDevice: {
        for (const device of root.devices) {
            if (device.type === "ethernet" || device.type === "bridge")
                return device;
        }
        return null;
    }

    readonly property var ethernetDevice: {
        for (const device of root.devices) {
            if ((device.type === "ethernet" || device.type === "bridge") && device.state === "connected")
                return device;
        }
        return null;
    }

    readonly property bool wired: root.ethernetDevice !== null
    readonly property bool wifiConnected: root.wifiDevice !== null && root.wifiDevice.state === "connected"
    readonly property bool connected: root.wired || root.wifiConnected

    readonly property string ssid: root.wifiConnected ? root.wifiDevice.connection : ""

    readonly property var activeAccessPoint: {
        for (const point of root.accessPoints) {
            if (point.active)
                return point;
        }
        return null;
    }

    readonly property int signalStrength: root.activeAccessPoint ? root.activeAccessPoint.signal : 0

    readonly property string summary: {
        if (!root.available)
            return "NetworkManager not found";
        if (root.wired)
            return "Wired, " + (root.ethernetDevice.connection || root.ethernetDevice.device);
        if (root.wifiConnected)
            return root.ssid + ", " + root.signalStrength + "%";
        if (root.anyEthernetDevice && root.anyEthernetDevice.state === "disconnected")
            return "Wired (" + root.anyEthernetDevice.device + ") disconnected";
        if (!root.wifiRadio)
            return "Wi-Fi off";
        return "Offline";
    }

    function isSaved(name: string): bool {
        return root.savedNames.indexOf(name) !== -1;
    }

    // nmcli's terse output escapes a literal colon as \.
    function splitTerse(line: string): var {
        const fields = [];
        let current = "";
        let escaped = false;

        for (let index = 0; index < line.length; index++) {
            const character = line[index];

            if (escaped) {
                current += character;
                escaped = false;
            } else if (character === "\\") {
                escaped = true;
            } else if (character === ":") {
                fields.push(current);
                current = "";
            } else {
                current += character;
            }
        }

        fields.push(current);
        return fields;
    }

    function refresh(): void {
        if (!root.enabled || readProcess.running)
            return;

        // Carried on the process rather than read off root when it exits.
        readProcess.full = root.detailed;
        readProcess.rescanning = root.scanning;
        readProcess.command = ["sh", "-c", root.readScript, "qsbar-network", readProcess.full ? "full" : "brief", readProcess.rescanning ? "rescan" : "cache"];
        readProcess.running = true;
    }

    // A scan is a request, not a command.
    function rescan(): void {
        if (root.scanning || !root.enabled || !root.available)
            return;

        root.scanning = true;
        root.refresh();
    }

    function setWifiRadio(on: bool): void {
        root.runQueue([["nmcli", "radio", "wifi", on ? "on" : "off"]], "");
    }

    function disconnect(): void {
        if (!root.wifiDevice)
            return;

        root.runQueue([["nmcli", "device", "disconnect", root.wifiDevice.device]], "");
    }

    function connectEthernet(deviceName: string): void {
        const target = deviceName || (root.anyEthernetDevice ? root.anyEthernetDevice.device : "");
        if (!root.usableName(target))
            return;

        root.runQueue([
            ["nmcli", "device", "set", target, "autoconnect", "yes"],
            ["nmcli", "device", "connect", target]
        ], "");
    }

    function disconnectEthernet(deviceName: string): void {
        const target = deviceName || (root.ethernetDevice ? root.ethernetDevice.device : "");
        if (!root.usableName(target))
            return;

        root.runQueue([["nmcli", "device", "disconnect", target]], "");
    }

    function toggleEthernet(deviceName: string, currentlyConnected: bool): void {
        if (currentlyConnected)
            root.disconnectEthernet(deviceName);
        else
            root.connectEthernet(deviceName);
    }

    function enforceStartupPolicy(): void {
        if (!Settings.loaded) {
            startupPolicyConn.enabled = true;
            return;
        }
        if (root.startupPolicyApplied)
            return;
        root.startupPolicyApplied = true;
        startupPolicyProcess.command = ["sh", "-c", root.startupPolicyScript, "qsbar-net-startup", Settings.vpnAutoconnect ? "1" : "0"];
        startupPolicyProcess.running = true;
    }

    function setVpnAutoconnectGlobal(allow: bool): void {
        Settings.vpnAutoconnect = allow;
        vpnAutoconnectProcess.command = ["sh", "-c", root.vpnAutoconnectScript, "qsbar-vpn-auto", allow ? "yes" : "no"];
        vpnAutoconnectProcess.running = true;
    }

    function setVpnProfileAutoconnect(name: string, allow: bool): void {
        if (!root.usableName(name))
            return;
        root.runQueue([["nmcli", "connection", "modify", "id", name, "connection.autoconnect", allow ? "yes" : "no"]], "");
    }

    // nmcli takes the ssid positionally, but a leading dash is the kind of thing an option parser changes its mind about.
    function usableName(name: string): bool {
        if (!name || name.startsWith("-")) {
            root.lastError = "Unusable network name";
            return false;
        }
        return true;
    }

    function connectSaved(name: string): void {
        if (!root.usableName(name))
            return;

        root.runQueue([["nmcli", "connection", "up", "id", name]], "");
    }

    function connectOpen(name: string): void {
        if (!root.usableName(name))
            return;

        root.runQueue([["nmcli", "device", "wifi", "connect", name]], "");
    }

    // --ask makes nmcli its own secret agent and read what it is missing from stdin.
    function connectPersonal(name: string, password: string): void {
        if (!root.usableName(name))
            return;

        root.runQueue([["nmcli", "--ask", "device", "wifi", "connect", name]], password);
    }

    function connectHidden(name: string, password: string): void {
        if (!root.usableName(name))
            return;

        if (password && password.length > 0)
            root.runQueue([["nmcli", "--ask", "device", "wifi", "connect", name, "hidden", "yes"]], password);
        else
            root.runQueue([["nmcli", "device", "wifi", "connect", name, "hidden", "yes"]], "");
    }

    function setIpv6Method(method: string): void {
        const allowed = ["auto", "disabled", "ignore", "link-local"];
        if (allowed.indexOf(method) === -1 || !root.usableName(root.activeConnection))
            return;

        root.runQueue([
            ["nmcli", "connection", "modify", "id", root.activeConnection, "ipv6.method", method],
            ["nmcli", "connection", "up", "id", root.activeConnection]
        ], "");
    }

    function setAutoconnect(enabled: bool): void {
        if (!root.usableName(root.activeConnection))
            return;

        root.runQueue([
            ["nmcli", "connection", "modify", "id", root.activeConnection, "connection.autoconnect", enabled ? "yes" : "no"]
        ], "");
    }

    function setMacMode(mode: string): void {
        const allowed = ["permanent", "random", "stable"];
        if (allowed.indexOf(mode) === -1 || !root.usableName(root.activeConnection))
            return;

        root.runQueue([
            ["nmcli", "connection", "modify", "id", root.activeConnection, "802-11-wireless.cloned-mac-address", mode],
            ["nmcli", "connection", "up", "id", root.activeConnection]
        ], "");
    }

    function setDnsPreset(preset: string, customList: string): void {
        if (!root.usableName(root.activeConnection))
            return;

        let args;
        if (preset === "auto") {
            args = ["ipv4.ignore-auto-dns", "no", "ipv4.dns", "", "ipv6.ignore-auto-dns", "no", "ipv6.dns", ""];
        } else if (preset === "cloudflare") {
            args = ["ipv4.ignore-auto-dns", "yes", "ipv4.dns", "1.1.1.1 1.0.0.1", "ipv6.ignore-auto-dns", "yes", "ipv6.dns", "2606:4700:4700::1111 2606:4700:4700::1001"];
        } else if (preset === "google") {
            args = ["ipv4.ignore-auto-dns", "yes", "ipv4.dns", "8.8.8.8 8.8.4.4", "ipv6.ignore-auto-dns", "yes", "ipv6.dns", "2001:4860:4860::8888 2001:4860:4860::8844"];
        } else if (preset === "quad9") {
            args = ["ipv4.ignore-auto-dns", "yes", "ipv4.dns", "9.9.9.9 149.112.112.112", "ipv6.ignore-auto-dns", "yes", "ipv6.dns", "2620:fe::fe 2620:fe::9"];
        } else if (preset === "custom") {
            const tokens = String(customList || "").replace(/,/g, " ").trim().split(/\s+/).filter(t => t !== "");
            if (tokens.length === 0 || tokens.some(t => !/^[0-9a-fA-F.:]+$/.test(t))) {
                root.lastError = "Invalid DNS server list";
                return;
            }
            const v4 = tokens.filter(t => t.indexOf(":") === -1);
            const v6 = tokens.filter(t => t.indexOf(":") !== -1);
            args = [
                "ipv4.ignore-auto-dns", v4.length > 0 ? "yes" : "no",
                "ipv4.dns", v4.join(" "),
                "ipv6.ignore-auto-dns", v6.length > 0 ? "yes" : "no",
                "ipv6.dns", v6.join(" ")
            ];
        } else {
            return;
        }

        root.runQueue([
            ["nmcli", "connection", "modify", "id", root.activeConnection].concat(args),
            ["nmcli", "connection", "up", "id", root.activeConnection]
        ], "");
    }

    function setIpv4Auto(): void {
        if (!root.usableName(root.activeConnection))
            return;

        root.runQueue([
            ["nmcli", "connection", "modify", "id", root.activeConnection, "ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", ""],
            ["nmcli", "connection", "up", "id", root.activeConnection]
        ], "");
    }

    function setIpv4Manual(cidr: string, gw: string): void {
        if (!root.usableName(root.activeConnection))
            return;

        const cleanCidr = String(cidr || "").trim();
        const cleanGw = String(gw || "").trim();
        if (!/^\d{1,3}(\.\d{1,3}){3}\/\d{1,2}$/.test(cleanCidr)) {
            root.lastError = "IPv4 address must be in CIDR format (e.g. 192.168.1.50/24)";
            return;
        }
        if (cleanGw !== "" && !/^\d{1,3}(\.\d{1,3}){3}$/.test(cleanGw)) {
            root.lastError = "Invalid IPv4 gateway address";
            return;
        }

        root.runQueue([
            ["nmcli", "connection", "modify", "id", root.activeConnection, "ipv4.method", "manual", "ipv4.addresses", cleanCidr, "ipv4.gateway", cleanGw],
            ["nmcli", "connection", "up", "id", root.activeConnection]
        ], "");
    }

    function startHotspot(ssid: string, password: string): void {
        if (!root.wifiDevice) {
            root.lastError = "No Wi-Fi device available for hotspot";
            return;
        }
        const cleanSsid = String(ssid || "").trim();
        const cleanPass = String(password || "");
        if (!root.usableName(cleanSsid))
            return;
        if (cleanPass !== "" && cleanPass.length < 8) {
            root.lastError = "Hotspot password must be at least 8 characters";
            return;
        }
        const cmd = ["nmcli", "device", "wifi", "hotspot", "ifname", root.wifiDevice.device, "ssid", cleanSsid];
        if (cleanPass !== "")
            cmd.push("password", cleanPass);
        root.runQueue([cmd], "");
    }

    function stopHotspot(): void {
        if (!root.wifiDevice)
            return;
        if (root.hotspotActive && root.activeConnection !== "")
            root.runQueue([["nmcli", "connection", "down", "id", root.activeConnection]], "");
        else
            root.runQueue([["nmcli", "device", "disconnect", root.wifiDevice.device]], "");
    }

    function copyText(value: string): void {
        const text = String(value || "").trim();
        if (text === "")
            return;
        Quickshell.execDetached(["wl-copy", "--", text]);
    }

    function revealWifiPassword(): void {
        if (!root.available || !root.wifiConnected || !root.usableName(root.activeConnection))
            return;
        if (secretProcess.running)
            return;
        root.lastError = "";
        secretProcess.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", "id", root.activeConnection];
        secretProcess.running = true;
    }

    function clearPassword(): void {
        root.revealedPassword = "";
    }

    // WPA Enterprise, which is what eduroam is.
    function connectEnterprise(name: string, identity: string, anonymous: string, password: string, eap: string, phase2: string, caCertificate: string): void {
        if (!root.usableName(name))
            return;

        if (!root.wifiDevice) {
            root.lastError = "No Wi-Fi device";
            return;
        }

        if (!identity) {
            root.lastError = "Identity is required";
            return;
        }

        const known = root.isSaved(name);
        const properties = ["wifi-sec.key-mgmt", "wpa-eap", "802-1x.eap", eap, "802-1x.phase2-auth", phase2, "802-1x.identity", identity, "802-1x.password-flags", "0"];

        // Optional, and only worth sending when there is something to send.
        for (const optional of [["802-1x.anonymous-identity", anonymous], ["802-1x.ca-cert", caCertificate]]) {
            if (optional[1] || known)
                properties.push(optional[0], optional[1] ? optional[1] : "");
        }

        const write = known ? ["nmcli", "connection", "modify", "id", name].concat(properties) : ["nmcli", "connection", "add", "type", "wifi", "con-name", name, "ifname", root.wifiDevice.device, "ssid", name].concat(properties);

        root.runQueue([write, ["nmcli", "--ask", "connection", "up", "id", name]], password);
    }

    function forget(name: string): void {
        if (!root.usableName(name))
            return;

        root.runQueue([["nmcli", "connection", "delete", "id", name]], "");
    }

    function connectVpn(name: string): void {
        if (!root.usableName(name))
            return;

        root.runQueue([["nmcli", "connection", "up", "id", name]], "");
    }

    function disconnectVpn(name: string): void {
        if (!root.usableName(name))
            return;

        root.runQueue([["nmcli", "connection", "down", "id", name]], "");
    }

    function toggleVpn(name: string, currentlyActive: bool): void {
        if (currentlyActive)
            root.disconnectVpn(name);
        else
            root.connectVpn(name);
    }

    function importWireguard(path: string): void {
        const raw = String(path || "").trim();
        if (raw === "")
            return;
        const home = Quickshell.env("HOME") || "/home";
        const cleaned = raw.startsWith("file://") ? raw.slice(7) : raw;
        const full = cleaned.startsWith("~/") ? home + cleaned.slice(1) : cleaned;
        if (!full.startsWith("/")) {
            root.lastError = "Not an absolute path: " + raw;
            return;
        }
        root.runQueue([["nmcli", "connection", "import", "type", "wireguard", "file", full]], "");
    }

    // Commands run one after the other and stop at the first failure.
    property var queue: []
    property string queueSecret: ""

    function runQueue(commands: var, secret: string): void {
        if (root.busy || !root.available)
            return;

        root.busy = true;
        root.lastError = "";
        root.queue = commands;
        root.queueSecret = secret;
        root.nextStep();
    }

    function nextStep(): void {
        if (root.queue.length === 0) {
            root.finishQueue();
            return;
        }

        const step = root.queue[0];
        root.queue = root.queue.slice(1);

        actionProcess.wantsSecret = step.indexOf("--ask") !== -1;
        actionProcess.stdinEnabled = actionProcess.wantsSecret;
        actionProcess.command = step;
        actionProcess.running = true;
    }

    function finishQueue(): void {
        root.queue = [];
        root.queueSecret = "";
        root.busy = false;
        root.refresh();
    }

    readonly property string startupPolicyScript: `command -v nmcli >/dev/null 2>&1 || exit 0
export LC_ALL=C
allow_vpn="$1"

# 1. If VPN autoconnect on startup is disabled (default: 0), disable autoconnect on VPN/WireGuard profiles and bring down any that auto-started.
if [ "$allow_vpn" != "1" ]; then
    nmcli -t -f UUID,TYPE,AUTOCONNECT,ACTIVE connection show 2>/dev/null | while IFS=: read -r uuid ctype autoconn active; do
        if [ "$ctype" = "vpn" ] || [ "$ctype" = "wireguard" ]; then
            if [ "$autoconn" = "yes" ]; then
                nmcli connection modify uuid "$uuid" connection.autoconnect no >/dev/null 2>&1 || true
            fi
            if [ "$active" = "yes" ]; then
                nmcli connection down uuid "$uuid" >/dev/null 2>&1 || true
            fi
        fi
    done
fi

# 2. Ensure all ethernet profiles have autoconnect enabled and connect any plugged-in ethernet interface left in 'disconnected' state.
nmcli -t -f UUID,TYPE,AUTOCONNECT connection show 2>/dev/null | while IFS=: read -r uuid ctype autoconn; do
    if [ "$ctype" = "802-3-ethernet" ] && [ "$autoconn" = "no" ]; then
        nmcli connection modify uuid "$uuid" connection.autoconnect yes >/dev/null 2>&1 || true
    fi
done

nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | while IFS=: read -r dev dtype dstate; do
    if [ "$dtype" = "ethernet" ] && [ "$dstate" = "disconnected" ]; then
        nmcli device set "$dev" autoconnect yes >/dev/null 2>&1 || true
        nmcli device connect "$dev" >/dev/null 2>&1 || true
    fi
done
exit 0`

    readonly property string vpnAutoconnectScript: `command -v nmcli >/dev/null 2>&1 || exit 0
export LC_ALL=C
mode="$1"
nmcli -t -f UUID,TYPE connection show 2>/dev/null | while IFS=: read -r uuid ctype; do
    if [ "$ctype" = "vpn" ] || [ "$ctype" = "wireguard" ]; then
        nmcli connection modify uuid "$uuid" connection.autoconnect "$mode" >/dev/null 2>&1 || true
    fi
done
exit 0`

    readonly property string readScript: `command -v nmcli >/dev/null 2>&1 || exit 127
export LC_ALL=C
echo "#radio"
nmcli -t radio wifi 2>/dev/null
echo "#devices"
nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null
echo "#aps"
if [ "$2" = rescan ]; then
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan yes 2>/dev/null
elif [ "$1" = full ]; then
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null
else
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null | grep "^\\*"
fi
echo "#saved"
if [ "$1" = full ]; then
    nmcli -t -f NAME,TYPE,ACTIVE,AUTOCONNECT,DEVICE connection show 2>/dev/null
    echo "#ip"
    dev=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$3 == "connected" && ($2 == "ethernet" || $2 == "bridge") { print $1; found=1; exit } END { if (!found) { } }')
    if [ -z "$dev" ]; then
        dev=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$3 == "connected" && $2 == "wifi" { print $1; exit }')
    fi
    if [ -n "$dev" ]; then
        nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.GATEWAY,IP6.DNS device show "$dev" 2>/dev/null
        con=$(nmcli -t -f DEVICE,CONNECTION device status 2>/dev/null | awk -F: -v d="$dev" '$1 == d { print $2; exit }')
        if [ -n "$con" ]; then
            printf 'CONN_NAME:%s\n' "$con"
            nmcli -t -f ipv4.method,ipv4.ignore-auto-dns,ipv4.dns,ipv6.method,connection.autoconnect,802-11-wireless.cloned-mac-address,802-11-wireless.mode connection show id "$con" 2>/dev/null
        fi
    fi
else
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null
fi
exit 0`

    function parse(text: string, full: bool): void {
        const devices = [];
        const points = [];
        const saved = [];
        const ethProfiles = [];
        const vpns = [];
        const activeVpns = [];
        let activeConnection = "";
        let ipAddress = "";
        let gateway = "";
        const dnsList = [];
        let ipv6Address = "";
        let ipv6Gateway = "";
        const dns6List = [];
        let ipv4Method = "auto";
        let ipv6Method = "auto";
        let ignoreAutoDns = false;
        let configuredDns = "";
        let autoconnect = true;
        let macMode = "permanent";
        let hotspotActive = false;
        let section = "";

        for (const line of text.split("\n")) {
            if (line === "")
                continue;

            if (line.startsWith("#")) {
                section = line.slice(1);
                continue;
            }

            if (section === "radio") {
                root.wifiRadio = line.trim() === "enabled";
                continue;
            }

            if (section === "ip") {
                const idx = line.indexOf(":");
                if (idx === -1)
                    continue;
                const key = line.slice(0, idx);
                const val = line.slice(idx + 1).trim().replace(/\\:/g, ":");
                if (!val)
                    continue;
                if (key === "CONN_NAME")
                    activeConnection = val;
                else if (key === "ipv4.method")
                    ipv4Method = val;
                else if (key === "ipv6.method")
                    ipv6Method = val;
                else if (key === "ipv4.ignore-auto-dns")
                    ignoreAutoDns = val === "yes";
                else if (key === "ipv4.dns")
                    configuredDns = val;
                else if (key === "connection.autoconnect")
                    autoconnect = val !== "no";
                else if (key === "802-11-wireless.cloned-mac-address")
                    macMode = (val === "random" || val === "stable") ? val : "permanent";
                else if (key === "802-11-wireless.mode")
                    hotspotActive = val === "ap";
                else if (key.startsWith("IP4.ADDRESS") && ipAddress === "")
                    ipAddress = val;
                else if (key === "IP4.GATEWAY" && gateway === "")
                    gateway = val;
                else if (key.startsWith("IP4.DNS") && dnsList.indexOf(val) === -1)
                    dnsList.push(val);
                else if (key.startsWith("IP6.ADDRESS") && ipv6Address === "")
                    ipv6Address = val;
                else if (key === "IP6.GATEWAY" && ipv6Gateway === "")
                    ipv6Gateway = val;
                else if (key.startsWith("IP6.DNS") && dns6List.indexOf(val) === -1)
                    dns6List.push(val);
                continue;
            }

            const fields = root.splitTerse(line);

            if (section === "devices" && fields.length >= 4) {
                devices.push({
                    device: fields[0],
                    type: fields[1],
                    state: fields[2],
                    connection: fields[3]
                });
            } else if (section === "aps" && fields.length >= 4 && fields[1] !== "") {
                const security = fields[3];
                points.push({
                    ssid: fields[1],
                    signal: parseInt(fields[2], 10) || 0,
                    security: security,
                    enterprise: security.indexOf("802.1X") !== -1,
                    active: fields[0] === "*"
                });
            } else if (section === "saved" && fields.length >= 2) {
                const connName = fields[0];
                const connType = fields[1];
                if (full) {
                    const isActive = fields.length >= 3 && fields[2] === "yes";
                    const isAuto = fields.length < 4 || fields[3] !== "no";
                    const connDev = fields.length >= 5 ? fields[4] : "";
                    if (connType === "802-11-wireless")
                        saved.push(connName);
                    if (connType === "802-3-ethernet") {
                        ethProfiles.push({
                            name: connName,
                            type: connType,
                            active: isActive,
                            autoconnect: isAuto,
                            device: connDev
                        });
                    }
                    if (connType === "wireguard" || connType === "vpn") {
                        vpns.push({
                            name: connName,
                            type: connType,
                            active: isActive,
                            autoconnect: isAuto
                        });
                        if (isActive && activeVpns.indexOf(connName) === -1)
                            activeVpns.push(connName);
                    }
                } else {
                    if ((connType === "wireguard" || connType === "vpn") && activeVpns.indexOf(connName) === -1)
                        activeVpns.push(connName);
                }
            }
        }

        // Also catch WireGuard interfaces reported in #devices even if connection metadata differs.
        for (const dev of devices) {
            if (dev.type === "wireguard" && dev.state === "connected") {
                const label = dev.connection || dev.device;
                if (label && activeVpns.indexOf(label) === -1)
                    activeVpns.push(label);
            }
        }

        root.devices = devices;
        root.activeVpnNames = activeVpns;
        if (full) {
            root.savedNames = saved;
            root.ethernetProfiles = ethProfiles;
            vpns.sort((a, b) => (a.active === b.active) ? a.name.localeCompare(b.name) : (a.active ? -1 : 1));
            root.vpns = vpns;
            if (root.activeConnection !== activeConnection)
                root.revealedPassword = "";
            root.activeConnection = activeConnection;
            root.ipAddress = ipAddress;
            root.gateway = gateway;
            root.dnsServers = dnsList.join(", ");
            root.ipv6Address = ipv6Address;
            root.ipv6Gateway = ipv6Gateway;
            root.ipv6Dns = dns6List.join(", ");
            root.ipv4Method = ipv4Method;
            root.ipv6Method = ipv6Method;
            root.autoconnect = autoconnect;
            root.macMode = macMode;
            root.hotspotActive = hotspotActive;
            if (!ignoreAutoDns || configuredDns === "") {
                root.dnsPreset = "auto";
                root.customDns = "";
            } else {
                const norm = configuredDns.replace(/,/g, " ").trim().replace(/\s+/g, " ");
                if (norm === "1.1.1.1 1.0.0.1" || norm === "1.1.1.1")
                    root.dnsPreset = "cloudflare";
                else if (norm === "8.8.8.8 8.8.4.4" || norm === "8.8.8.8")
                    root.dnsPreset = "google";
                else if (norm === "9.9.9.9 149.112.112.112" || norm === "9.9.9.9")
                    root.dnsPreset = "quad9";
                else
                    root.dnsPreset = "custom";
                root.customDns = norm;
            }
        }

        // A brief read only ever carries the active access point.
        root.accessPoints = full ? points : root.mergeActive(points);
    }

    function mergeActive(points: var): var {
        if (points.length === 0)
            return root.accessPoints.map(point => Object.assign({}, point, {
                active: false
            }));

        const active = points[0];
        let matched = false;

        const merged = root.accessPoints.map(point => {
            if (point.ssid !== active.ssid)
                return Object.assign({}, point, {
                    active: false
                });
            matched = true;
            return active;
        });

        return matched ? merged : merged.concat([active]);
    }

    Connections {
        id: startupPolicyConn

        target: Settings
        enabled: false

        function onLoadedChanged(): void {
            if (Settings.loaded) {
                startupPolicyConn.enabled = false;
                root.enforceStartupPolicy();
            }
        }
    }

    Process {
        id: startupPolicyProcess

        onExited: {
            if (root.enabled)
                root.refresh();
        }
    }

    Process {
        id: vpnAutoconnectProcess

        onExited: {
            if (root.enabled)
                root.refresh();
        }
    }

    Process {
        id: readProcess

        property bool full: false
        property bool rescanning: false

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text, readProcess.full)
        }

        onExited: (exitCode, exitStatus) => {
            root.available = exitCode !== 127;
            if (!root.available) {
                root.lastError = "nmcli is not installed";
                root.scanning = false;
                return;
            }

            if (readProcess.rescanning)
                root.scanning = false;

            if (root.enabled && ((root.detailed && !readProcess.full) || (root.scanning && !readProcess.rescanning)))
                root.refresh();
        }
    }

    Process {
        id: actionProcess

        property bool wantsSecret: false

        stderr: StdioCollector {
            onStreamFinished: {
                const message = this.text.trim();
                if (message !== "")
                    root.lastError = message.split("\n")[0];
            }
        }

        // The secret goes in the moment the pipe exists and the pipe is closed straight after.
        onStarted: {
            if (!actionProcess.wantsSecret)
                return;

            actionProcess.write(root.queueSecret + "\n");
            actionProcess.stdinEnabled = false;
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if (root.lastError === "")
                    root.lastError = "Command failed with status " + exitCode;
                root.finishQueue();
                return;
            }

            root.nextStep();
        }
    }

    Process {
        id: secretProcess

        stdout: StdioCollector {
            onStreamFinished: root.revealedPassword = this.text.trim()
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.lastError = "Could not read saved Wi-Fi password";
        }
    }

    // `nmcli monitor` is one process for the session that prints a line whenever a device, connection or radio changes state.
    Process {
        id: monitorProcess

        command: ["nmcli", "monitor"]

        stdout: SplitParser {
            onRead: settleTimer.restart()
        }
    }

    // nmcli monitor reports one user action as a run of lines.
    Timer {
        id: settleTimer

        interval: 250
        onTriggered: root.refresh()
    }

    Timer {
        // Started from the tick rather than from a binding on `running`.
        interval: root.detailed ? root.activeInterval : monitorProcess.running ? root.watchedInterval : root.idleInterval
        running: root.enabled && root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!monitorProcess.running)
                monitorProcess.running = true;
            root.refresh();
        }
    }

    onEnabledChanged: {
        if (root.enabled) {
            root.refresh();
        } else {
            root.scanning = false;
            monitorProcess.running = false;
            settleTimer.stop();
        }
    }

    onDetailedChanged: {
        if (root.detailed)
            root.refresh();
        else
            root.scanning = false;
    }
}
