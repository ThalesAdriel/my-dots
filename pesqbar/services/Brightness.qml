pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// Screen brightness, from whichever of the two things this machine has. A
// laptop has a backlight, and brightnessctl drives it the same way the
// XF86MonBrightness keys do (hypr/hyprland/scripts/brightness.sh). A desktop
// has none, and dimming there is hyprsunset's gamma: a curve over the output
// rather than a panel that actually gets darker, but the same control as far as
// the hand on the slider is concerned.
Singleton {
    id: root

    // "backlight", "gamma", or "" for a machine with neither, which is the one
    // case the control center leaves the row out for.
    property string backend: ""
    readonly property bool available: root.backend !== ""

    // Set while the control center is open. Only the backlight is worth
    // re-reading: the keys can move it underneath, and gamma has nothing to
    // read back from in the first place.
    property bool watching: false

    property int backlightPercent: 0

    // hyprsunset has no getter for the gamma it is applying right now:
    // `hyprctl hyprsunset profile` prints the configured profile rather than
    // what is on the screen. So on that backend the shell owns the number, and
    // remembers it across a reload rather than coming back up showing 100% over
    // a screen that is still at 40.
    readonly property int percent: root.backend === "gamma" ? Settings.gammaBrightness : root.backlightPercent

    // A backlight at 1% is still a lit panel you can find the slider on. Gamma
    // at 1% is a black screen with the pointer lost somewhere in it, and the
    // only way back would be a terminal you also cannot see, so that one stops
    // a long way short.
    readonly property int minimumPercent: root.backend === "gamma" ? 10 : 1

    // What the slider is holding mid drag. A drag hands over a new value on
    // every mouse move, and a process per pixel is both slow and pointless
    // since only the last one matters, so the write is coalesced below and the
    // slider reads this until the backend has caught up. -1 means idle.
    property int pending: -1
    readonly property int level: root.pending >= 0 ? root.pending : root.percent

    // Both questions in one go: what this machine can dim, and where it is set.
    // brightnessctl prints nothing and exits non-zero with no backlight class
    // device, which is what a desktop looks like; hyprsunset is the fallback,
    // and it is already started from the same hyprland.start block the shell is.
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

    // The backend on the first line, and for a backlight the brightnessctl line
    // under it: "intel_backlight,backlight,49876,52%,96000" is the device, its
    // class, the raw value, the percentage and the maximum.
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

        // Only once nothing is still on its way to the backend: clearing it
        // while a write is queued would snap the slider back to the level the
        // read was taken at, under the pointer that is still dragging it.
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
            // A backlight says what it landed on, and rounding means that is
            // not always what it was asked for. Gamma has nothing to ask.
            if (root.backend === "backlight") {
                root.refresh();
                return;
            }

            if (!applyTimer.running)
                root.pending = -1;
        }
    }

    // Short enough to feel like the slider is driving the screen directly, long
    // enough that a drag across the panel is a handful of writes rather than
    // one per frame.
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
                // Remembered as it is applied rather than after: the two have to
                // move together, or a reload shows one while the screen is at
                // the other.
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

    // hyprsunset comes up on its profile's gamma, which is not necessarily the
    // one that was on screen when the shell last ran. Both are started from the
    // same hyprland.start block and the shell is first in it, so this is on a
    // delay rather than straight away: a call that lands before hyprsunset is
    // listening does nothing at all.
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

    // One probe at startup rather than on first open: the control center needs
    // to know whether there is anything to dim before it lays itself out, and
    // finding out as the panel opens would pop the row in and resize it under
    // the pointer.
    Component.onCompleted: root.refresh()
}
