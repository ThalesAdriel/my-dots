import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "root:/config"

// The idle timeouts and the game options in settings reach hypridle and Hyprland as files they read themselves.
Scope {
    id: root

    readonly property string hyprDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr"

    // A whole number of minutes, 0 or more, whatever settings.json holds.
    function minutes(value: var): int {
        return Math.max(0, Math.round(Number(value) || 0));
    }

    // One of Hyprland's 0, 1 or 2, or 0.
    function mode(value: var): int {
        return [0, 1, 2].indexOf(value) !== -1 ? value : 0;
    }

    // The same file the dotfiles ship, down to the byte while the timeouts are the defaults.
    readonly property string idleText: {
        const blocks = ["$power = sh $HOME/.config/hypr/hyprland/scripts/power.sh\n$lock = sh $HOME/.config/quicklock/quicklock", "general {\n    lock_cmd = $lock\n    before_sleep_cmd = $power lock\n    inhibit_sleep = 3\n}"];
        const listener = (after, lines) => {
            if (after > 0)
                blocks.push("listener {\n    timeout = " + after * 60 + "\n" + lines.map(line => "    " + line + "\n").join("") + "}");
        };
        listener(root.minutes(Settings.idleLockMinutes), ["on-timeout = $power lock"]);
        listener(root.minutes(Settings.idleScreenOffMinutes), ["on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'", "on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'"]);
        listener(root.minutes(Settings.idleSuspendMinutes), ["on-timeout = $power suspend"]);
        return blocks.join("\n\n") + "\n";
    }

    readonly property int vrr: root.mode(Settings.vrr)
    readonly property int directScanout: root.mode(Settings.directScanout)
    readonly property string gamingText: "hl.config({ misc = { vrr = " + root.vrr + " }, render = { direct_scanout = " + root.directScanout + " } })\n"

    function sync(): void {
        if (!Settings.loaded)
            return;

        if (idleFile.text() !== root.idleText) {
            idleFile.setText(root.idleText);
            // Detached, so hypridle outlives the shell that restarted it.
            Quickshell.execDetached(["sh", "-c", "pkill -x hypridle; i=0; while pgrep -x hypridle >/dev/null && [ $i -lt 30 ]; do sleep 0.1; i=$((i + 1)); done; exec hypridle"]);
        }

        if (gamingFile.text() !== root.gamingText) {
            gamingFile.setText(root.gamingText);
            Quickshell.execDetached(Hyprland.usingLua ? ["hyprctl", "eval", root.gamingText] : ["hyprctl", "--batch", "keyword misc:vrr " + root.vrr + " ; keyword render:direct_scanout " + root.directScanout]);
        }
    }

    // Settings arrive a value at a time, and a slider hands over one per mouse move.
    onIdleTextChanged: syncTimer.restart()
    onGamingTextChanged: syncTimer.restart()

    Connections {
        target: Settings

        function onLoadedChanged(): void {
            syncTimer.restart();
        }
    }

    Timer {
        id: syncTimer

        interval: 600
        onTriggered: root.sync()
    }

    // Usually symlinks into a dotfiles checkout, like monitors.lua.
    FileView {
        id: idleFile

        path: root.hyprDir + "/hypridle.conf"
        blockLoading: true
        atomicWrites: false
        printErrors: false
    }

    FileView {
        id: gamingFile

        path: root.hyprDir + "/hyprland/gaming.lua"
        blockLoading: true
        atomicWrites: false
        printErrors: false
    }
}
