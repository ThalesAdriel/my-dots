pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// Whether the screen is being recorded, the way macOS reports it. gpu-screen-recorder is one process either way.
Singleton {
    id: root

    readonly property bool enabled: Settings.showRecording

    // The probe scans /proc/*/comm with shell builtins (0 child forks when idle).
    readonly property int idleInterval: 10000
    readonly property int activeInterval: 5000
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

    // /proc/<pid>/comm truncates "gpu-screen-recorder" (19 chars) to 15 chars: "gpu-screen-reco".
    // Filtering comm first avoids spawning pgrep -f and reading every process's cmdline on the system.
    readonly property string script: `for f in /proc/[0-9]*/comm; do
    read -r c <"$f" 2>/dev/null || continue
    [ "$c" = "gpu-screen-reco" ] || continue
    pid=\${f#/proc/}; pid=\${pid%/comm}
    cmd=$(tr '\\000' '\\n' <"/proc/$pid/cmdline" 2>/dev/null) || continue
    first=\${cmd%%
*}
    case "$first" in
        */gpu-screen-recorder|gpu-screen-recorder) ;;
        *) continue ;;
    esac
    case "
$cmd
" in
        *"
-r
"*) continue ;;
    esac
    ps -o etimes= -p "$pid" 2>/dev/null | tr -d " "
    exit 0
done
exit 0`

    Process {
        id: probe

        command: ["sh", "-c", root.script, "qsbar-recording"]

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

    // Resyncs against /proc on the probe interval.
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

    // Smooth 1s local tick while recording, without extra subprocesses.
    Timer {
        interval: 1000
        running: root.enabled && root.active
        repeat: true
        onTriggered: root.elapsed += 1
    }

    onEnabledChanged: {
        if (!root.enabled) {
            root.active = false;
            root.elapsed = 0;
        }
    }
}
