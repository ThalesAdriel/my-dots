pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// power-profiles-daemon through powerprofilesctl, read on demand rather than on a timer: a profile only changes because something asked it to, and only the battery panel shows it.
Singleton {
    id: root

    readonly property bool enabled: Settings.showBattery

    // Set while the battery panel is open, which is the one time an outside change is worth catching quickly.
    property bool detailed: false

    property bool available: true
    property string active: ""
    property var profiles: []
    property string lastError: ""

    readonly property var order: ["performance", "balanced", "power-saver"]

    readonly property var labels: ({
        "performance": "Performance",
        "balanced": "Balanced",
        "power-saver": "Power saver"
    })

    readonly property var glyphs: ({
        "performance": Glyphs.gaugeHigh,
        "balanced": Glyphs.scaleBalanced,
        "power-saver": Glyphs.leaf
    })

    // Sorted the way the panel lists them, and only the ones this machine offers: a desktop without a performance profile should not be shown a button that fails.
    readonly property var sortedProfiles: root.profiles.slice().sort((left, right) => {
        const leftIndex = root.order.indexOf(left);
        const rightIndex = root.order.indexOf(right);
        return (leftIndex === -1 ? root.order.length : leftIndex) - (rightIndex === -1 ? root.order.length : rightIndex);
    })

    function label(profile: string): string {
        return root.labels[profile] !== undefined ? root.labels[profile] : profile;
    }

    function glyph(profile: string): string {
        return root.glyphs[profile] !== undefined ? root.glyphs[profile] : Glyphs.scaleBalanced;
    }

    function refresh(): void {
        if (!root.enabled || readProcess.running)
            return;

        readProcess.running = true;
    }

    function set(profile: string): void {
        if (setProcess.running || root.profiles.indexOf(profile) === -1)
            return;

        root.lastError = "";
        setProcess.command = ["powerprofilesctl", "set", profile];
        setProcess.running = true;
    }

    readonly property string readScript: `command -v powerprofilesctl >/dev/null 2>&1 || exit 127
export LC_ALL=C
echo "#active"
powerprofilesctl get 2>/dev/null
echo "#list"
powerprofilesctl list 2>/dev/null
exit 0`

    function parse(text: string): void {
        const names = [];
        let section = "";
        let active = "";

        for (const line of text.split("\n")) {
            if (line === "")
                continue;

            if (line.startsWith("#")) {
                section = line.slice(1);
                continue;
            }

            if (section === "active") {
                active = line.trim();
                continue;
            }

            // "* balanced:" for the active one, "  performance:" for the rest; everything below a heading is indented further and has no trailing colon, so the anchor tells them apart.
            const match = line.match(/^(\*?)\s*([a-z][a-z0-9-]*):\s*$/);
            if (match)
                names.push(match[2]);
        }

        root.profiles = names;
        root.active = active;
    }

    Process {
        id: readProcess

        command: ["sh", "-c", root.readScript, "pesqbar-power"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }

        onExited: (exitCode, exitStatus) => {
            root.available = exitCode !== 127;
            if (!root.available)
                root.lastError = "power-profiles-daemon is not installed";
        }
    }

    Process {
        id: setProcess

        stderr: StdioCollector {
            onStreamFinished: {
                const message = this.text.trim();
                if (message !== "")
                    root.lastError = message.split("\n")[0];
            }
        }

        onExited: root.refresh()
    }

    Timer {
        interval: 5000
        running: root.enabled && root.detailed && root.available
        repeat: true
        onTriggered: root.refresh()
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
