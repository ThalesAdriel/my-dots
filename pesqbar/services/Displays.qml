pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// The monitor layout, read out of hyprctl and written back with it.
//
// hyprctl reports a monitor's mode in physical pixels and its position in
// logical ones, so the two only agree once the scale is divided out. Everything
// below works in logical coordinates, which is what the arrangement is actually
// in, and converts back at the edges.
//
// Nothing is written to the Hyprland config. The layout lives in the shell's own
// settings.json and is applied with `hyprctl keyword` when the bar comes up,
// which works the same whether the config is hyprlang or Lua and undoes itself
// by being deleted.
Singleton {
    id: root

    // Polled while the settings sheet is open. The rest of the time the layout
    // is only read when something changes it.
    property bool watching: false

    property bool available: true
    property string lastError: ""

    // [{ name, description, x, y, width, height, refresh, scale,
    //    modes: [{ width, height, refresh, label }] }]
    property var monitors: []

    // What the panel is editing: name -> { x, y, width, height, refresh, scale }.
    // Held apart from `monitors` so an edit survives the next poll.
    property var draft: ({})
    property string selected: ""

    property bool previewing: false
    property int previewSeconds: 0
    property bool identifying: false

    // What was on screen before a preview started, so it can be put back.
    property var previousLayout: ({})

    // A saved layout is put back once, when the monitors are first read. Doing
    // it on every read would fight anyone changing a monitor by hand.
    property bool restored: false

    readonly property int previewTimeout: 12

    readonly property var scaleOptions: [1, 1.25, 1.5, 1.75, 2]

    readonly property bool hasSavedLayout: {
        const saved = Settings.displayLayout;
        return !!saved && Object.keys(saved).length > 0;
    }

    readonly property bool dirty: {
        for (const monitor of root.monitors) {
            const entry = root.draft[monitor.name];
            if (!entry)
                continue;
            if (entry.x !== monitor.x || entry.y !== monitor.y)
                return true;
            if (entry.width !== monitor.width || entry.height !== monitor.height)
                return true;
            if (Math.abs(entry.refresh - monitor.refresh) > 0.01)
                return true;
            if (Math.abs(entry.scale - monitor.scale) > 0.001)
                return true;
        }
        return false;
    }

    function entryFor(name: string): var {
        return root.draft[name] !== undefined ? root.draft[name] : null;
    }

    function logicalSize(entry: var): var {
        return {
            width: Math.round(entry.width / entry.scale),
            height: Math.round(entry.height / entry.scale)
        };
    }

    function indexOf(name: string): int {
        for (let index = 0; index < root.monitors.length; index++) {
            if (root.monitors[index].name === name)
                return index;
        }
        return -1;
    }

    // Hyprland's own names, so this is not about escaping anything a stranger
    // sent. It is that the spec below is joined into one batch string with ; and
    // , as separators, and a name has to be unable to reach either.
    function usableName(name: string): bool {
        return /^[A-Za-z0-9_.:-]+$/.test(name);
    }

    // The same argument for the numbers, and a stronger one: a saved layout is
    // read back out of settings.json, which is a file on disk that anything can
    // edit, and every one of these ends up interpolated into that batch string.
    // A value that is not a plain number in a sane range does not get that far.
    function sanitiseEntry(entry: var): var {
        if (!entry)
            return null;

        const clean = {};
        for (const key of ["x", "y", "width", "height", "refresh", "scale"]) {
            const value = Number(entry[key]);
            if (!isFinite(value))
                return null;
            clean[key] = value;
        }

        if (clean.width <= 0 || clean.width > 32768 || clean.height <= 0 || clean.height > 32768)
            return null;
        if (clean.refresh <= 0 || clean.refresh > 1000)
            return null;
        if (clean.scale < 0.1 || clean.scale > 10)
            return null;
        if (Math.abs(clean.x) > 100000 || Math.abs(clean.y) > 100000)
            return null;

        clean.x = Math.round(clean.x);
        clean.y = Math.round(clean.y);
        clean.width = Math.round(clean.width);
        clean.height = Math.round(clean.height);
        return clean;
    }

    function modeLabel(mode: var): string {
        return mode.width + " × " + mode.height + "  @  " + mode.refresh.toFixed(2) + " Hz";
    }

    // "1920x1080@164.96Hz"
    function parseMode(text: string): var {
        const match = String(text).match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
        if (!match)
            return null;

        const mode = {
            width: parseInt(match[1], 10),
            height: parseInt(match[2], 10),
            refresh: parseFloat(match[3])
        };
        mode.label = root.modeLabel(mode);
        return mode;
    }

    function refresh(): void {
        if (readProcess.running)
            return;
        readProcess.running = true;
    }

    function parse(text: string): void {
        let payload = [];
        try {
            payload = JSON.parse(text);
        } catch (error) {
            root.available = false;
            root.lastError = "hyprctl returned something that is not JSON";
            return;
        }

        if (!Array.isArray(payload))
            return;

        const list = [];
        for (const item of payload) {
            if (!item || !root.usableName(item.name))
                continue;

            // A disabled output reports 0x0 at 0 Hz. There is nothing to place
            // and nothing here that turns one back on, so it is left out rather
            // than drawn as an eight pixel stub with a nonsense mode.
            if (item.disabled === true || !(item.width > 0) || !(item.height > 0))
                continue;

            const scale = item.scale > 0 ? item.scale : 1;
            const modes = [];
            const seen = {};

            for (const descriptor of (item.availableModes || [])) {
                const mode = root.parseMode(descriptor);
                if (!mode || seen[mode.label])
                    continue;
                seen[mode.label] = true;
                modes.push(mode);
            }

            // Whatever it is running now belongs in the list even when the
            // driver did not report it as available.
            const current = {
                width: item.width,
                height: item.height,
                refresh: item.refreshRate
            };
            current.label = root.modeLabel(current);
            if (!seen[current.label])
                modes.unshift(current);

            list.push({
                name: item.name,
                description: item.description || item.name,
                x: item.x,
                y: item.y,
                width: item.width,
                height: item.height,
                refresh: item.refreshRate,
                scale: scale,
                modes: modes
            });
        }

        root.monitors = list;
        root.available = true;

        if (root.selected === "" || root.indexOf(root.selected) === -1)
            root.selected = list.length > 0 ? list[0].name : "";

        // An edit in progress owns the draft; a poll must not pull it back to
        // what the compositor is still showing.
        if (!root.dirty || Object.keys(root.draft).length === 0)
            root.syncDraft();

        root.restore();
    }

    function syncDraft(): void {
        const next = {};
        for (const monitor of root.monitors) {
            next[monitor.name] = {
                x: monitor.x,
                y: monitor.y,
                width: monitor.width,
                height: monitor.height,
                refresh: monitor.refresh,
                scale: monitor.scale
            };
        }
        root.draft = next;
    }

    function update(name: string, changes: var): void {
        const entry = root.draft[name];
        if (!entry)
            return;

        const next = {};
        for (const key of Object.keys(root.draft))
            next[key] = Object.assign({}, root.draft[key]);

        Object.assign(next[name], changes);
        root.draft = next;
    }

    // hyprctl wants physical mode, logical position and scale, in that order.
    function spec(name: string, entry: var): string {
        return name + "," + entry.width + "x" + entry.height + "@" + entry.refresh.toFixed(2) + "," + entry.x + "x" + entry.y + "," + entry.scale;
    }

    function apply(layout: var): void {
        const steps = [];
        for (const name of Object.keys(layout)) {
            const entry = root.usableName(name) ? root.sanitiseEntry(layout[name]) : null;
            if (entry)
                steps.push("keyword monitor " + root.spec(name, entry));
        }

        if (steps.length === 0)
            return;

        // One batch rather than a call each, so the monitors never sit in a
        // half moved arrangement between two of them.
        root.lastError = "";
        applyProcess.command = ["hyprctl", "--batch", steps.join(" ; ")];
        applyProcess.running = true;
    }

    function liveLayout(): var {
        const layout = {};
        for (const monitor of root.monitors) {
            layout[monitor.name] = {
                x: monitor.x,
                y: monitor.y,
                width: monitor.width,
                height: monitor.height,
                refresh: monitor.refresh,
                scale: monitor.scale
            };
        }
        return layout;
    }

    // Applies the draft for a while and puts the old arrangement back on its
    // own. A layout that leaves a screen dark cannot be undone from a panel
    // nobody can see, so nothing here is permanent until it is confirmed.
    function preview(): void {
        if (root.previewing)
            return;

        previousLayout = root.liveLayout();
        root.previewing = true;
        root.previewSeconds = root.previewTimeout;
        root.apply(root.draft);
        previewTimer.start();
    }

    function cancelPreview(revert: bool): void {
        if (!root.previewing)
            return;

        previewTimer.stop();
        root.previewing = false;
        root.previewSeconds = 0;

        if (revert)
            root.apply(root.previousLayout);
    }

    function save(): void {
        // The layout is on screen already, so the restore below has nothing to
        // put back and should not run when the setting lands.
        root.restored = true;
        root.cancelPreview(false);
        root.apply(root.draft);

        const layout = {};
        for (const name of Object.keys(root.draft))
            layout[name] = Object.assign({}, root.draft[name]);

        Settings.displayLayout = layout;
    }

    // Back to what the compositor itself is showing, and nothing remembered:
    // the next session gets whatever Hyprland works out on its own.
    function reset(): void {
        root.cancelPreview(true);
        Settings.displayLayout = ({});
        root.syncDraft();
    }

    function identify(): void {
        root.identifying = true;
        identifyTimer.restart();
    }

    function restore(): void {
        if (root.restored || root.monitors.length === 0)
            return;

        // Not marked done until there is something to be done: settings.json is
        // read asynchronously, so the first hyprctl answer usually beats it and
        // an unconditional flag here would drop the saved layout on every boot.
        const saved = Settings.displayLayout;
        if (!saved || Object.keys(saved).length === 0)
            return;

        root.restored = true;

        // Only the monitors that are actually plugged in, and only if the
        // arrangement is not already the one that was saved.
        const layout = {};
        let differs = false;

        for (const monitor of root.monitors) {
            const entry = root.sanitiseEntry(saved[monitor.name]);
            if (!entry)
                continue;

            layout[monitor.name] = entry;
            if (entry.x !== monitor.x || entry.y !== monitor.y || entry.width !== monitor.width || entry.height !== monitor.height || Math.abs(entry.scale - monitor.scale) > 0.001 || Math.abs(entry.refresh - monitor.refresh) > 0.01)
                differs = true;
        }

        if (differs)
            root.apply(layout);
    }

    // settings.json can finish loading after the monitors have been read, which
    // is when a saved layout arrives too late for the read that would apply it.
    Connections {
        target: Settings

        function onDisplayLayoutChanged(): void {
            root.restore();
        }
    }

    Process {
        id: readProcess

        command: ["hyprctl", "-j", "monitors", "all"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.available = false;
                root.lastError = "hyprctl is not answering";
            }
        }
    }

    Process {
        id: applyProcess

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
        id: previewTimer

        interval: 1000
        repeat: true
        onTriggered: {
            root.previewSeconds -= 1;
            if (root.previewSeconds <= 0)
                root.cancelPreview(true);
        }
    }

    Timer {
        id: identifyTimer
        interval: 3000
        onTriggered: root.identifying = false
    }

    Timer {
        interval: 2500
        running: root.watching
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // One read at startup, which is what puts a saved layout back.
    Component.onCompleted: root.refresh()
}
