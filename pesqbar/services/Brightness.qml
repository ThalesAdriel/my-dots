pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// Screen brightness from whichever of the two this machine has: a laptop's backlight through brightnessctl, or hyprsunset's gamma curve on a desktop with none.
Singleton {
    id: root

    // "backlight", "gamma", or "" for a machine with neither, which is the one case the control center leaves the row out for.
    property string backend: ""
    readonly property bool available: root.backend !== ""

    // Set while the control center is open; only the backlight is worth re-reading, since the keys can move it underneath and gamma has nothing to read back from.
    property bool watching: false

    property int backlightPercent: 0

    // hyprsunset has no getter for the gamma it is applying, so on that backend the shell owns the number and remembers it across a reload.
    readonly property int percent: root.backend === "gamma" ? Settings.gammaBrightness : root.backlightPercent

    // A backlight at 1% is still a lit panel you can find the slider on; gamma at 1% is a black screen with no way back, so that one stops a long way short.
    readonly property int minimumPercent: root.backend === "gamma" ? 10 : 1

    // What the slider is holding mid drag, since only the last value matters and a process per pixel is pointless; -1 means idle.
    property int pending: -1
    readonly property int level: root.pending >= 0 ? root.pending : root.percent

    // Both questions in one go, what this machine can dim and where it is set: brightnessctl exits non-zero with no backlight device, and hyprsunset is the fallback.
    readonly property string probeScript: `line=$(brightnessctl -m 2>/dev/null) || line=
case $line in
*,*,*,*)
	printf 'backlight\\n%s\\n' "$line"
	exit 0
	;;
esac

command -v hyprctl >/dev/null 2>&1 && echo gamma
exit 0`

    function refresh(): void {
        if (readProcess.running)
            return;

        readProcess.running = true;
    }

    function set(value: real): void {
        const clamped = Math.min(Math.max(Math.round(value), root.minimumPercent), 100);
        if (!root.available || clamped === root.level)
            return;

        root.pending = clamped;
        applyTimer.restart();
    }

    // The backend on the first line, and under it the brightnessctl line: device, class, raw value, percentage and maximum.
    function parse(text: string): void {
        const lines = text.trim().split("\n");
        const named = lines.length > 0 ? lines[0].trim() : "";

        if (named === "backlight") {
            const fields = (lines.length > 1 ? lines[1] : "").split(",");
            const value = fields.length >= 4 ? parseInt(fields[3], 10) : NaN;

            if (isNaN(value)) {
                root.backend = "";
                return;
            }

            root.backend = "backlight";
            root.backlightPercent = Math.min(Math.max(value, 0), 100);
        } else if (named === "gamma") {
            root.backend = "gamma";
        } else {
            root.backend = "";
            return;
        }

        // Only once nothing is still on its way to the backend, or the slider would snap back to the read's level under a pointer that is still dragging it.
        if (!applyTimer.running && !setProcess.running)
            root.pending = -1;
    }

    Process {
        id: readProcess

        command: ["sh", "-c", root.probeScript, "pesqbar-brightness"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Process {
        id: setProcess

        onExited: {
            // A backlight says what it landed on, and rounding means that is not always what it was asked for; gamma has nothing to ask.
            if (root.backend === "backlight") {
                root.refresh();
                return;
            }

            if (!applyTimer.running)
                root.pending = -1;
        }
    }

    // Short enough to feel like the slider drives the screen directly, long enough that a drag is a handful of writes rather than one per frame.
    Timer {
        id: applyTimer

        interval: 60

        onTriggered: {
            if (setProcess.running) {
                applyTimer.restart();
                return;
            }

            const value = root.pending;
            if (root.backend === "gamma") {
                // Remembered as it is applied rather than after, or a reload shows one number while the screen is at another.
                Settings.gammaBrightness = value;
                setProcess.command = ["hyprctl", "hyprsunset", "gamma", String(value)];
            } else {
                setProcess.command = ["brightnessctl", "-m", "set", value + "%"];
            }

            setProcess.running = true;
        }
    }

    Timer {
        interval: 2000
        running: root.watching && root.backend === "backlight" && root.pending < 0
        repeat: true
        onTriggered: root.refresh()
    }

    // hyprsunset comes up on its profile's gamma and starts from the same hyprland.start block, so this waits: a call that lands before it is listening does nothing.
    Timer {
        interval: 3000
        running: root.backend === "gamma" && Settings.gammaBrightness !== 100
        repeat: false

        onTriggered: Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", String(Settings.gammaBrightness)])
    }

    onWatchingChanged: {
        if (root.watching)
            root.refresh();
    }

    // One probe at startup rather than on first open, so the control center knows whether there is anything to dim before it lays itself out.
    Component.onCompleted: root.refresh()
}
