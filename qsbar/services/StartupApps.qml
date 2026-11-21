pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User-configured applications started with Hyprland, persisted directly to hypr/hyprland/autostart.lua.
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hyprland/autostart.lua"

    // [{ name, command, delay, enabled, minimized }]
    property var entries: []
    property bool loaded: false
    property string lastError: ""

    readonly property var defaultEntries: [
        {
            name: "qBittorrent",
            command: "flatpak run org.qbittorrent.qBittorrent",
            delay: 4,
            enabled: true,
            minimized: false
        }
    ]

    function formatDesktopCommand(entry: var): string {
        if (!entry || !entry.command)
            return "";
        const fieldCodes = /^%[fFuUdDnNickvm]$|^@@u?$|^@@$/;
        const parts = [];
        for (let i = 0; i < entry.command.length; i++) {
            const arg = String(entry.command[i] || "");
            if (arg === "" || fieldCodes.test(arg))
                continue;
            parts.push(/\s/.test(arg) ? '"' + arg.replace(/"/g, '\\"') + '"' : arg);
        }
        const cmd = parts.join(" ");
        if (cmd === "")
            return "";
        return entry.runInTerminal ? "kitty -1 " + cmd : cmd;
    }

    // Installed desktop applications from Quickshell's native DesktopEntries (zero forks).
    readonly property var installedApps: {
        const raw = DesktopEntries.applications ? DesktopEntries.applications.values : [];
        const list = [];
        const seen = {};
        for (let i = 0; i < raw.length; i++) {
            const entry = raw[i];
            if (!entry || entry.noDisplay)
                continue;
            const name = String(entry.name || "").trim();
            const cmd = root.formatDesktopCommand(entry);
            if (name === "" || cmd === "")
                continue;
            const key = entry.id || (name + "|" + cmd);
            if (seen[key])
                continue;
            seen[key] = true;
            list.push({
                id: key,
                name: name,
                command: cmd,
                icon: entry.icon || "",
                comment: entry.comment || ""
            });
        }
        list.sort((a, b) => a.name.localeCompare(b.name));
        return list;
    }

    function clampDelay(value: var): int {
        const n = Math.round(Number(value) || 0);
        return Math.max(0, Math.min(60, n));
    }

    function escapeLua(value: string): string {
        return String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\r?\n/g, " ");
    }

    function parse(text: string): var {
        const match = /^--\s*qsbar-autostart:\s*(\[.*\])\s*$/m.exec(text || "");
        if (!match)
            return null;
        try {
            const parsed = JSON.parse(match[1]);
            if (!Array.isArray(parsed))
                return null;
            return parsed
                .filter(item => item && typeof item.command === "string" && item.command.trim() !== "")
                .map(item => ({
                    name: (typeof item.name === "string" && item.name.trim() !== "") ? item.name.trim() : item.command.trim().split(/\s+/)[0],
                    command: item.command.trim(),
                    delay: root.clampDelay(item.delay),
                    enabled: item.enabled !== false,
                    minimized: item.minimized === true
                }));
        } catch (e) {
            return null;
        }
    }

    function serialise(): string {
        const lines = [
            "-- Managed by qsbar Settings -> Startup apps.",
            "-- qsbar-autostart: " + JSON.stringify(root.entries),
            "",
            'hl.on("hyprland.start", function()'
        ];
        for (const item of root.entries) {
            if (!item.enabled || !item.command)
                continue;
            const rawCmd = item.minimized ? "[workspace special:magic silent] " + item.command : item.command;
            const cmd = root.escapeLua(rawCmd);
            if (item.delay > 0) {
                lines.push("\thl.timer(function()");
                lines.push('\t\thl.exec_cmd("' + cmd + '")');
                lines.push("\tend, { timeout = " + (item.delay * 1000) + ', type = "oneshot" })');
            } else {
                lines.push('\thl.exec_cmd("' + cmd + '")');
            }
        }
        lines.push("end)");
        return lines.join("\n") + "\n";
    }

    function save(): void {
        root.lastError = "";
        file.setText(root.serialise());
    }

    function add(name: string, command: string, delay: int, minimized: bool): bool {
        const trimmedCmd = String(command || "").trim();
        if (trimmedCmd === "") {
            root.lastError = "Command cannot be empty.";
            return false;
        }
        const trimmedName = String(name || "").trim() || trimmedCmd.split(/\s+/)[0];
        const next = root.entries.slice();
        next.push({
            name: trimmedName,
            command: trimmedCmd,
            delay: root.clampDelay(delay),
            enabled: true,
            minimized: minimized === true
        });
        root.entries = next;
        root.save();
        return true;
    }

    function remove(index: int): void {
        if (index < 0 || index >= root.entries.length)
            return;
        const next = root.entries.slice();
        next.splice(index, 1);
        root.entries = next;
        root.save();
    }

    function toggle(index: int): void {
        if (index < 0 || index >= root.entries.length)
            return;
        const next = root.entries.slice();
        const cur = next[index];
        next[index] = {
            name: cur.name,
            command: cur.command,
            delay: cur.delay,
            enabled: !cur.enabled,
            minimized: cur.minimized
        };
        root.entries = next;
        root.save();
    }

    function toggleMinimized(index: int): void {
        if (index < 0 || index >= root.entries.length)
            return;
        const next = root.entries.slice();
        const cur = next[index];
        next[index] = {
            name: cur.name,
            command: cur.command,
            delay: cur.delay,
            enabled: cur.enabled,
            minimized: !cur.minimized
        };
        root.entries = next;
        root.save();
    }

    function setDelay(index: int, delay: int): void {
        if (index < 0 || index >= root.entries.length)
            return;
        const clamped = root.clampDelay(delay);
        const cur = root.entries[index];
        if (cur.delay === clamped)
            return;
        const next = root.entries.slice();
        next[index] = {
            name: cur.name,
            command: cur.command,
            delay: clamped,
            enabled: cur.enabled,
            minimized: cur.minimized
        };
        root.entries = next;
        root.save();
    }

    function launchNow(command: string, minimized: bool): void {
        const cmd = String(command || "").trim();
        if (cmd === "")
            return;
        if (minimized)
            Quickshell.execDetached(["hyprctl", "dispatch", "exec", "[workspace special:magic silent] " + cmd]);
        else
            Quickshell.execDetached(["sh", "-c", cmd]);
    }

    FileView {
        id: file

        path: root.path
        blockLoading: true
        atomicWrites: false
        watchChanges: true
        printErrors: false

        onFileChanged: file.reload()

        onLoaded: {
            const parsed = root.parse(file.text());
            root.entries = parsed !== null ? parsed : root.defaultEntries.slice();
            root.loaded = true;
        }

        onLoadFailed: {
            root.entries = root.defaultEntries.slice();
            root.loaded = true;
        }
    }
}
