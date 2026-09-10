pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// BlueZ through bluetoothctl, the same shape as the network service: one tagged-section read, a queue for the writes, addresses checked against the shape of a MAC, argv arrays throughout, and every call wrapped in timeout so a hung daemon cannot pile up processes.
Singleton {
    id: root

    readonly property bool enabled: Settings.showBluetooth

    property bool detailed: false

    // Stays a poll: bluetoothctl has no monitor mode worth running and eavesdropping on bluez over the system bus is root only, so it costs less per tick and ticks less often instead.
    readonly property int idleInterval: 10000
    readonly property int activeInterval: 2500

    property bool available: true
    property bool powered: false
    property bool scanning: false
    property bool busy: false
    property string lastError: ""

    // [{ address, name, paired, connected }]
    property var devices: []

    readonly property var connectedDevices: root.devices.filter(device => device.connected)

    readonly property bool anyConnected: root.connectedDevices.length > 0

    readonly property string summary: {
        if (!root.available)
            return "bluetoothctl not found";
        if (!root.powered)
            return "Bluetooth off";
        if (root.connectedDevices.length === 1)
            return root.connectedDevices[0].name;
        if (root.connectedDevices.length > 1)
            return root.connectedDevices.length + " devices connected";
        return "Bluetooth on";
    }

    // Not about escaping, since nothing below reaches a shell: a device is free to call itself anything, and only the address is worth handing back to bluetoothctl.
    function isAddress(address: string): bool {
        return /^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$/.test(address);
    }

    function refresh(): void {
        if (!root.enabled || readProcess.running)
            return;

        readProcess.command = ["sh", "-c", root.readScript, "pesqbar-bluetooth", root.detailed ? "full" : "brief"];
        readProcess.running = true;
    }

    function setPowered(on: bool): void {
        root.runQueue([["bluetoothctl", "power", on ? "on" : "off"]]);
    }

    function scan(): void {
        if (root.scanning)
            return;

        root.scanning = true;
        scanTimer.restart();

        // Runs on its own rather than through the queue: it holds the process open for its whole duration, and the panel has to stay usable while devices are still arriving.
        scanProcess.running = true;
    }

    function connectDevice(address: string): void {
        if (!root.isAddress(address)) {
            root.lastError = "Not a device address";
            return;
        }

        root.runQueue([["timeout", "25", "bluetoothctl", "connect", address]]);
    }

    function disconnectDevice(address: string): void {
        if (!root.isAddress(address)) {
            root.lastError = "Not a device address";
            return;
        }

        root.runQueue([["timeout", "15", "bluetoothctl", "disconnect", address]]);
    }

    // Pairing without an agent only gets through where the device asks nothing of the user; anything wanting a passkey has to be paired with bluetoothctl itself.
    function pairDevice(address: string): void {
        if (!root.isAddress(address)) {
            root.lastError = "Not a device address";
            return;
        }

        root.runQueue([["timeout", "30", "bluetoothctl", "pair", address], ["bluetoothctl", "trust", address], ["timeout", "25", "bluetoothctl", "connect", address]]);
    }

    function forgetDevice(address: string): void {
        if (!root.isAddress(address)) {
            root.lastError = "Not a device address";
            return;
        }

        root.runQueue([["timeout", "15", "bluetoothctl", "remove", address]]);
    }

    property var queue: []

    function runQueue(commands: var): void {
        if (root.busy)
            return;

        root.busy = true;
        root.lastError = "";
        root.queue = commands;
        root.nextStep();
    }

    function nextStep(): void {
        if (root.queue.length === 0) {
            root.busy = false;
            root.refresh();
            return;
        }

        const step = root.queue[0];
        root.queue = root.queue.slice(1);
        actionProcess.command = step;
        actionProcess.running = true;
    }

    // devices Paired and devices Connected arrived in bluez 5.65; the fallback catches an older bluetoothctl that can only list the paired ones.
    readonly property string readScript: `command -v bluetoothctl >/dev/null 2>&1 || exit 127
export LC_ALL=C
echo "#adapter"
timeout 5 bluetoothctl show 2>/dev/null
echo "#connected"
timeout 5 bluetoothctl devices Connected 2>/dev/null | grep "^Device "
# The paired list is the panel's, and the panel is the only thing that reads
# the flag. A brief read is the bar indicator asking whether anything is
# connected, and does not need two more bluetoothctl runs to answer that.
if [ "$1" = full ]; then
    echo "#paired"
    timeout 5 bluetoothctl devices Paired 2>/dev/null | grep "^Device " || timeout 5 bluetoothctl paired-devices 2>/dev/null | grep "^Device "
    echo "#seen"
    timeout 5 bluetoothctl devices 2>/dev/null | grep "^Device "
fi
exit 0`

    function parse(text: string): void {
        const table = {};
        const order = [];
        let section = "";
        let powered = false;

        const entry = (address, label) => {
            if (!table[address]) {
                table[address] = {
                    address: address,
                    name: label || address,
                    paired: false,
                    connected: false
                };
                order.push(address);
            } else if (label && table[address].name === address) {
                table[address].name = label;
            }
            return table[address];
        };

        for (const line of text.split("\n")) {
            if (line === "")
                continue;

            if (line.startsWith("#")) {
                section = line.slice(1);
                continue;
            }

            if (section === "adapter") {
                const trimmed = line.trim();
                if (trimmed.startsWith("Powered:"))
                    powered = trimmed.slice(8).trim() === "yes";
                continue;
            }

            // Device AA:BB:CC:DD:EE:FF Some name with spaces
            const match = line.match(/^Device\s+([0-9A-Fa-f:]{17})\s*(.*)$/);
            if (!match || !root.isAddress(match[1]))
                continue;

            const device = entry(match[1], match[2].trim());
            if (section === "paired")
                device.paired = true;
            else if (section === "connected")
                device.connected = true;
        }

        root.powered = powered;
        root.devices = order.map(address => table[address]);
    }

    Process {
        id: readProcess

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }

        onExited: (exitCode, exitStatus) => {
            root.available = exitCode !== 127;
            if (!root.available)
                root.lastError = "bluetoothctl is not installed";
        }
    }

    Process {
        id: actionProcess

        stderr: StdioCollector {
            onStreamFinished: {
                const message = this.text.trim();
                if (message !== "")
                    root.lastError = message.split("\n")[0];
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if (root.lastError === "")
                    root.lastError = "Command failed with status " + exitCode;
                root.queue = [];
                root.busy = false;
                root.refresh();
                return;
            }

            root.nextStep();
        }
    }

    Process {
        id: scanProcess
        command: ["bluetoothctl", "--timeout", "12", "scan", "on"]
        onExited: root.refresh()
    }

    Timer {
        interval: root.detailed ? root.activeInterval : root.idleInterval
        running: root.enabled && root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: scanTimer
        interval: 13000
        onTriggered: root.scanning = false
    }

    onEnabledChanged: {
        if (root.enabled)
            root.refresh();
    }

    onDetailedChanged: {
        if (root.detailed)
            root.refresh();
    }
}
