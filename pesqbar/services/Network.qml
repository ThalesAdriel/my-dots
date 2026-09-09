pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// NetworkManager through nmcli, since Quickshell has no network service: one polling read that builds the whole picture, and a queue for the writes. Commands are argv arrays so nothing a network names itself becomes a command, and passwords go in on stdin because argv is world readable through /proc/<pid>/cmdline.
Singleton {
    id: root

    // Nothing runs until the module is on screen: the poll is the only cost a network indicator carries, so it is not paid while it is off.
    readonly property bool enabled: Settings.showNetwork

    // The panel needs the access point list and the saved profiles and the bar needs neither, so this is set while the panel is open.
    property bool detailed: false

    readonly property int idleInterval: 6000
    readonly property int activeInterval: 2500

    // What the poll drops to once `nmcli monitor` is carrying the state changes; it does not stop, since signal strength is not a state change and a dead monitor has to be noticed.
    readonly property int watchedInterval: 60000

    property bool available: true
    property bool wifiRadio: true
    property bool scanning: false
    property bool busy: false
    property string lastError: ""

    // [{ device, type, state, connection }]
    property var devices: []
    // [{ ssid, signal, security, enterprise, active }]
    property var accessPoints: []
    property var savedNames: []

    readonly property var wifiDevice: {
        for (const device of root.devices) {
            if (device.type === "wifi")
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
            return "Wired, " + root.ethernetDevice.connection;
        if (root.wifiConnected)
            return root.ssid + ", " + root.signalStrength + "%";
        if (!root.wifiRadio)
            return "Wi-Fi off";
        return "Offline";
    }

    function isSaved(name: string): bool {
        return root.savedNames.indexOf(name) !== -1;
    }

    // nmcli's terse output escapes a literal colon as \: and a backslash as \\, which matters the moment a BSSID or an SSID with a colon shows up.
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

        // Carried on the process rather than read off root when it exits: a read already in flight when the scan was asked for is not the one that scanned.
        readProcess.rescanning = root.scanning;
        readProcess.command = ["sh", "-c", root.readScript, "pesqbar-network", root.detailed ? "full" : "brief", root.scanning ? "rescan" : "cache"];
        readProcess.running = true;
    }

    // A scan is a request, not a command: the flag stays up until a read that actually carried --rescan yes comes back, so asking mid-read is not dropped.
    function rescan(): void {
        if (root.scanning || !root.available)
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

    // nmcli takes the ssid positionally, but a leading dash is the kind of thing an option parser changes its mind about, so it is refused rather than guessed at.
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

    // --ask makes nmcli its own secret agent and read what it is missing from stdin, which is the whole point: the password never becomes an argument.
    function connectPersonal(name: string, password: string): void {
        if (!root.usableName(name))
            return;

        root.runQueue([["nmcli", "--ask", "device", "wifi", "connect", name]], password);
    }

    // WPA Enterprise, which is what eduroam is: the profile is written without the password, then brought up with --ask so it arrives on stdin, and password-flags 0 has NetworkManager store it root-owned and 0600 so it is only typed once.
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

        // Optional, and only worth sending when there is something to send; on an existing profile they go in empty as well, since that is what clears one that used to be set.
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

    // Commands run one after the other and stop at the first failure; the secret is held for the length of the queue and only given to a step that asked for one.
    property var queue: []
    property string queueSecret: ""

    function runQueue(commands: var, secret: string): void {
        if (root.busy)
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
    nmcli -t -f NAME,TYPE connection show 2>/dev/null
fi
exit 0`

    function parse(text: string): void {
        const devices = [];
        const points = [];
        const saved = [];
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
            } else if (section === "saved" && fields.length >= 2 && fields[1] === "802-11-wireless") {
                saved.push(fields[0]);
            }
        }

        root.devices = devices;
        root.savedNames = saved;

        // A brief read only ever carries the active access point, so it folds into the list the panel is showing rather than replacing it.
        root.accessPoints = root.detailed ? points : root.mergeActive(points);
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

    Process {
        id: readProcess

        property bool rescanning: false

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }

        onExited: (exitCode, exitStatus) => {
            root.available = exitCode !== 127;
            if (!root.available)
                root.lastError = "nmcli is not installed";

            if (readProcess.rescanning)
                root.scanning = false;
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

        // The secret goes in the moment the pipe exists and the pipe is closed straight after, so a prompt for anything else ends in EOF rather than leaving nmcli waiting.
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

    // `nmcli monitor` is one process for the session that prints a line whenever a device, connection or radio changes state, so the read runs off that rather than the clock: in steady state, the difference between four processes every six seconds and none.
    Process {
        id: monitorProcess

        command: ["nmcli", "monitor"]

        stdout: SplitParser {
            onRead: settleTimer.restart()
        }
    }

    // nmcli monitor reports one user action as a run of lines, so they collapse into one read on the trailing edge rather than one read each.
    Timer {
        id: settleTimer

        interval: 250
        onTriggered: root.refresh()
    }

    Timer {
        // Started from the tick rather than from a binding on `running`: a monitor that cannot start exits immediately, and a binding would respawn it as fast as it fails.
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
