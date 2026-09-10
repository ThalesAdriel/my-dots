pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// Whether the screen is being recorded, the way macOS reports it. gpu-screen-recorder is one process either way, so the flags separate a recording from a replay buffer: -r is left running all day without writing, and lighting the indicator for that would light it permanently.
Singleton {
    id: root

    readonly property bool enabled: Settings.showRecording

    // The probe walks every process in /proc and reads each cmdline, which is not worth doing twenty four times a minute on the chance a recorder turns up, so it scans slowly until something is recording and only then ticks to keep the elapsed time moving.
    readonly property int idleInterval: 10000
    readonly property int activeInterval: 2500
    readonly property int interval: root.active ? root.activeInterval : root.idleInterval

    property bool active: false
    property int elapsed: 0

    readonly property string elapsedLabel: {
        const total = root.elapsed;
        const seconds = total % 60;
        const minutes = Math.floor(total / 60) % 60;
        const hours = Math.floor(total / 3600);

        const padded = value => value < 10 ? "0" + value : String(value);
        return hours > 0 ? hours + ":" + padded(minutes) + ":" + padded(seconds) : minutes + ":" + padded(seconds);
    }

    // pgrep -x matches /proc/<pid>/comm, truncated to 15 characters, and gpu-screen-recorder is 19 long, so it could never match; -f casts wider than it should and argv[0] decides, which also throws out this script. grep -z reads NUL separated arguments as records, so -x matches an argument that is exactly -r.
    readonly property string script: `command -v pgrep >/dev/null 2>&1 || exit 127
for pid in $(pgrep -f gpu-screen-recorder 2>/dev/null); do
    first=$(tr '\\000' '\\n' < "/proc/$pid/cmdline" 2>/dev/null | head -n 1)
    case "$first" in
        */gpu-screen-recorder|gpu-screen-recorder) ;;
        *) continue ;;
    esac
    grep -qzx -- "-r" "/proc/$pid/cmdline" 2>/dev/null && continue
    ps -o etimes= -p "$pid" 2>/dev/null | tr -d " "
    exit 0
done
exit 0`

    Process {
        id: probe

        command: ["sh", "-c", root.script, "pesqbar-recording"]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim();
                const seconds = parseInt(value, 10);

                if (value === "" || isNaN(seconds)) {
                    root.active = false;
                    root.elapsed = 0;
                    return;
                }

                root.active = true;
                root.elapsed = seconds;
            }
        }
    }

    // Runs on the tick rather than counting locally, so the elapsed time is the recorder's own and survives the shell being restarted mid recording.
    Timer {
        interval: root.interval
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
    }

    onEnabledChanged: {
        if (!root.enabled) {
            root.active = false;
            root.elapsed = 0;
        }
    }
}
