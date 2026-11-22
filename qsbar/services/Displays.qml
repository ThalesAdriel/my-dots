pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "root:/config"

// The monitor layout, read out of hyprctl and written back with it.
Singleton {
    id: root

    // Polled while the settings sheet is open.
    property bool watching: false

    property bool available: true
    property string lastError: ""

    // [{ name, description, x, y, width, height, refresh, scale, disabled, transform, modes }].
    property var monitors: []

    // What the panel is editing.
    property var draft: ({})
    property string selected: ""

    property bool previewing: false
    property int previewSeconds: 0
    property bool identifying: false

    // What was on screen before a preview started, so it can be put back.
    property var previousLayout: ({})

    // A saved layout is put back once, when the monitors are first read.
    property bool restored: false

    readonly property int previewTimeout: 12

    readonly property var scaleOptions: [1, 1.25, 1.5, 1.75, 2]
    readonly property var transformOptions: [0, 1, 2, 3]

    function transformLabel(transform: int): string {
        return (transform * 90) + "°";
    }

    readonly property bool hasSavedLayout: {
        const saved = Settings.displayLayout;
        return !!saved && Object.keys(saved).length > 0;
    }

    readonly property bool dirty: {
        for (const monitor of root.monitors) {
            const entry = root.draft[monitor.name];
            if (!entry)
                continue;
            if (!!entry.disabled !== !!monitor.disabled)
                return true;
            if ((entry.transform || 0) !== (monitor.transform || 0))
                return true;
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

    function enabledCount(layout: var): int {
        if (!layout)
            return 0;
        let count = 0;
        for (const key of Object.keys(layout)) {
            const entry = layout[key];
            if (entry && !entry.disabled)
                count += 1;
        }
        return count;
    }

    function canDisable(name: string): bool {
        const entry = root.draft[name];
        if (!entry || entry.disabled)
            return false;
        return root.enabledCount(root.draft) > 1;
    }

    function logicalSize(entry: var): var {
        if (!entry)
            return {
                width: 0,
                height: 0
            };
        const scale = entry.scale > 0 ? entry.scale : 1;
        const w = Math.round(entry.width / scale);
        const h = Math.round(entry.height / scale);
        const t = entry.transform || 0;
        if (t === 1 || t === 3) {
            return {
                width: h,
                height: w
            };
        }
        return {
            width: w,
            height: h
        };
    }

    function indexOf(name: string): int {
        for (let index = 0; index < root.monitors.length; index++) {
            if (root.monitors[index].name === name)
                return index;
        }
        return -1;
    }

    // Hyprland's own names, so not about escaping a stranger's input.
    function usableName(name: string): bool {
        return /^[A-Za-z0-9_.:-]+$/.test(name);
    }

    // The same argument for the numbers, and a stronger one.
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
        clean.disabled = entry.disabled === true;

        const rawTransform = entry.transform === undefined ? 0 : Math.round(Number(entry.transform));
        if (!isFinite(rawTransform) || rawTransform < 0 || rawTransform > 3)
            return null;
        clean.transform = rawTransform;

        return clean;
    }

    function modeLabel(mode: var): string {
        return mode.width + " × " + mode.height + "  @  " + mode.refresh.toFixed(2) + " Hz";
    }

    // "1920x1080@164.96Hz".
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

            const disabled = item.disabled === true;
            const modes = [];
            const seen = {};

            for (const descriptor of (item.availableModes || [])) {
                const mode = root.parseMode(descriptor);
                if (!mode || seen[mode.label])
                    continue;
                seen[mode.label] = true;
                modes.push(mode);
            }

            // A disabled output often reports 0x0 at 0 Hz; fall back to its first mode so re-enabling works cleanly.
            let width = Number(item.width) > 0 ? Math.round(Number(item.width)) : (modes.length > 0 ? modes[0].width : 0);
            let height = Number(item.height) > 0 ? Math.round(Number(item.height)) : (modes.length > 0 ? modes[0].height : 0);
            const refresh = Number(item.refreshRate) > 0 ? Number(item.refreshRate) : (modes.length > 0 ? modes[0].refresh : 60);

            if (!disabled && (width <= 0 || height <= 0))
                continue;
            if (disabled && (width <= 0 || height <= 0)) {
                width = 1920;
                height = 1080;
            }

            const scale = item.scale > 0 ? item.scale : 1;
            const rawTransform = Math.round(Number(item.transform) || 0);
            const transform = rawTransform >= 0 && rawTransform <= 3 ? rawTransform : 0;
            const x = isFinite(Number(item.x)) ? Math.round(Number(item.x)) : 0;
            const y = isFinite(Number(item.y)) ? Math.round(Number(item.y)) : 0;

            // Whatever it is running now belongs in the list even when the driver did not report it as available.
            const current = {
                width: width,
                height: height,
                refresh: refresh
            };
            current.label = root.modeLabel(current);
            if (!seen[current.label])
                modes.unshift(current);

            list.push({
                name: item.name,
                description: item.description || item.name,
                x: x,
                y: y,
                width: width,
                height: height,
                refresh: refresh,
                scale: scale,
                disabled: disabled,
                transform: transform,
                modes: modes
            });
        }

        const wasAvailable = root.available;
        root.monitors = list;
        root.available = true;
        if (!wasAvailable)
            root.lastError = "";

        if (root.selected === "" || root.indexOf(root.selected) === -1)
            root.selected = list.length > 0 ? list[0].name : "";

        // An edit in progress owns the draft.
        if (!root.dirty || Object.keys(root.draft).length === 0)
            root.syncDraft();

        root.restore();
    }

    function syncDraft(): void {
        root.draft = root.liveLayout();
    }

    function update(name: string, changes: var): void {
        const entry = root.draft[name];
        if (!entry)
            return;

        // At least one monitor must stay enabled.
        if (changes && changes.disabled === true && !entry.disabled && root.enabledCount(root.draft) <= 1)
            return;

        const next = {};
        for (const key of Object.keys(root.draft))
            next[key] = Object.assign({}, root.draft[key]);

        Object.assign(next[name], changes);
        root.draft = next;
    }

    // hyprctl wants physical mode, logical position and scale, in that order.
    function spec(name: string, entry: var): string {
        if (entry.disabled)
            return name + ",disable";
        const base = name + "," + entry.width + "x" + entry.height + "@" + entry.refresh.toFixed(2) + "," + entry.x + "x" + entry.y + "," + entry.scale;
        return entry.transform ? base + ",transform," + entry.transform : base;
    }

    // The same monitor as the Lua config writes it, in the form general.lua uses for its own rules.
    function luaRule(name: string, entry: var): string {
        if (entry.disabled)
            return "hl.monitor({ output = \"" + name + "\", disable = true })";
        const transformPart = entry.transform ? ", transform = " + entry.transform : "";
        return "hl.monitor({ output = \"" + name + "\", mode = \"" + entry.width + "x" + entry.height + "@" + entry.refresh.toFixed(2) + "Hz\", position = \"" + entry.x + "x" + entry.y + "\", scale = \"" + entry.scale + "\"" + transformPart + " })";
    }

    function luaRules(layout: var): var {
        const rules = [];
        for (const name of Object.keys(layout)) {
            const entry = root.usableName(name) ? root.sanitiseEntry(layout[name]) : null;
            if (entry)
                rules.push(root.luaRule(name, entry));
        }
        return rules;
    }

    property var pendingApplyCommand: null

    function apply(layout: var): bool {
        if (!layout)
            return false;

        const entries = [];
        let enabled = 0;
        for (const name of Object.keys(layout)) {
            const entry = root.usableName(name) ? root.sanitiseEntry(layout[name]) : null;
            if (!entry)
                continue;
            entries.push({
                name: name,
                entry: entry
            });
            if (!entry.disabled)
                enabled += 1;
        }

        // Never allow applying a layout with no enabled monitors.
        if (entries.length === 0 || enabled === 0)
            return false;

        let command;
        if (Hyprland.usingLua) {
            const rules = [];
            for (const item of entries)
                rules.push(root.luaRule(item.name, item.entry));

            // One eval rather than a call each.
            command = ["hyprctl", "eval", rules.join(" ")];
        } else {
            const steps = [];
            for (const item of entries)
                steps.push("keyword monitor " + root.spec(item.name, item.entry));
            command = ["hyprctl", "--batch", steps.join(" ; ")];
        }

        root.lastError = "";
        if (applyProcess.running) {
            root.pendingApplyCommand = command;
            return true;
        }
        applyProcess.command = command;
        applyProcess.running = true;
        return true;
    }

    // An empty layout still writes the file, as a header alone.
    function writeMonitors(layout: var): void {
        const lines = ["-- Written by qsbar's display settings on every save; Reset there empties it, and general.lua's monitor rules apply again.", ""].concat(root.luaRules(layout));
        monitorsFile.setText(lines.join("\n") + "\n");
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
                scale: monitor.scale,
                disabled: !!monitor.disabled,
                transform: monitor.transform || 0
            };
        }
        return layout;
    }

    // Applies the draft for a while and puts the old arrangement back on its own.
    function preview(): void {
        if (root.previewing)
            return;

        const previous = root.liveLayout();
        if (!root.apply(root.draft))
            return;

        previousLayout = previous;
        root.previewing = true;
        root.previewSeconds = root.previewTimeout;
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
        // The layout is on screen already.
        root.restored = true;
        root.cancelPreview(false);
        root.apply(root.draft);

        const layout = {};
        for (const name of Object.keys(root.draft))
            layout[name] = Object.assign({}, root.draft[name]);

        Settings.displayLayout = layout;
        if (Hyprland.usingLua)
            root.writeMonitors(layout);
    }

    // Back to what the compositor itself is showing, and nothing remembered.
    function reset(): void {
        root.cancelPreview(!Hyprland.usingLua);
        Settings.displayLayout = ({});
        if (Hyprland.usingLua) {
            root.writeMonitors({});
            Quickshell.execDetached(["hyprctl", "reload"]);
        }
        root.syncDraft();
    }

    function identify(): void {
        root.identifying = true;
        identifyTimer.restart();
    }

    function restore(): void {
        if (root.restored || root.monitors.length === 0)
            return;

        // Not marked done until there is something to be done.
        const saved = Settings.displayLayout;
        if (!saved || Object.keys(saved).length === 0)
            return;

        root.restored = true;

        // Only the monitors that are actually plugged in.
        const layout = {};
        let differs = false;

        for (const monitor of root.monitors) {
            const entry = root.sanitiseEntry(saved[monitor.name]);
            if (!entry)
                continue;

            layout[monitor.name] = entry;
            if (entry.x !== monitor.x || entry.y !== monitor.y || entry.width !== monitor.width || entry.height !== monitor.height || Math.abs(entry.scale - monitor.scale) > 0.001 || Math.abs(entry.refresh - monitor.refresh) > 0.01 || !!entry.disabled !== !!monitor.disabled || (entry.transform || 0) !== (monitor.transform || 0))
                differs = true;
        }

        if (differs)
            root.apply(layout);
    }

    // settings.json can finish loading after the monitors have been read.
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

    // Usually a symlink into a dotfiles checkout, like theme.lua.
    FileView {
        id: monitorsFile

        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hyprland/monitors.lua"
        atomicWrites: false
        printErrors: false
    }

    Process {
        id: applyProcess

        // hyprctl answers on stdout and exits 0 whether or not the compositor took the keyword.
        stdout: StdioCollector {
            onStreamFinished: {
                // One reply per command in the batch, run together.
                const reply = this.text.trim();
                if (reply === "" || /^(ok\s*)+$/i.test(reply))
                    return;

                root.lastError = reply.split("\n")[0];
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = this.text.trim();
                if (message !== "")
                    root.lastError = message.split("\n")[0];
            }
        }

        onExited: {
            if (root.pendingApplyCommand !== null) {
                const next = root.pendingApplyCommand;
                root.pendingApplyCommand = null;
                applyProcess.command = next;
                applyProcess.running = true;
                return;
            }
            root.refresh();
        }
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
