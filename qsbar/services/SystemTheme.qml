pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The GTK, icon and cursor themes. hypr/hyprland/theme.lua is where they live, since Hyprland reads it at login for XCURSOR_* and the gsettings it hands out, so a change here is applied to the running session straight away and written back there for the next one.
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hyprland/theme.lua"

    // Whatever theme.lua returns, key to string or number. Other keys somebody added by hand are carried through a rewrite rather than dropped.
    property var values: ({})

    // False until theme.lua has been read: a change still applies to the session, but nothing is written over a file that was never seen.
    property bool loaded: false

    // theme.lua has no GTK theme until one is picked here, and until then the list shows whatever the session is actually using.
    property string liveGtkTheme: ""

    property var gtkThemes: []
    property var iconThemes: []
    property var cursorThemes: []

    readonly property string gtkTheme: root.values.gtk_theme !== undefined ? root.values.gtk_theme : root.liveGtkTheme
    readonly property string iconTheme: root.values.icon_theme !== undefined ? root.values.icon_theme : ""
    readonly property string cursorTheme: root.values.cursor_theme !== undefined ? root.values.cursor_theme : ""
    readonly property int cursorSize: root.values.cursor_size !== undefined ? root.values.cursor_size : 24

    readonly property var cursorSizes: [16, 20, 24, 32, 40, 48, 64]

    // execs.lua splices these into a shell line at login, so a name that could close a quote or start a second command never gets into the file, and one that starts with a dash would reach hyprctl and gsettings as a flag. Real theme names are directory names and fit comfortably.
    function usableName(name: string): bool {
        return /^[A-Za-z0-9][A-Za-z0-9 _.+@-]*$/.test(name);
    }

    function refresh(): void {
        if (!scan.running)
            scan.running = true;
        if (!gtkRead.running)
            gtkRead.running = true;
    }

    function parse(text: string): void {
        const next = {};
        const pattern = /(\w+)\s*=\s*(?:"([^"\\\n]*)"|(-?\d+(?:\.\d+)?))/g;
        let match;
        while ((match = pattern.exec(text)) !== null)
            next[match[1]] = match[2] !== undefined ? match[2] : Number(match[3]);

        root.values = next;
        root.loaded = true;
    }

    function serialise(): string {
        const lines = ["return {"];
        for (const key of Object.keys(root.values)) {
            const value = root.values[key];
            lines.push("\t" + key + " = " + (typeof value === "number" ? value : "\"" + value + "\"") + ",");
        }
        lines.push("}");
        return lines.join("\n") + "\n";
    }

    function set(key: string, value: var): void {
        if (typeof value === "string" && !root.usableName(value))
            return;

        const next = Object.assign({}, root.values);
        next[key] = value;
        root.values = next;

        const iface = "org.gnome.desktop.interface";
        if (key === "gtk_theme") {
            Quickshell.execDetached(["gsettings", "set", iface, "gtk-theme", value]);
        } else if (key === "icon_theme") {
            Quickshell.execDetached(["gsettings", "set", iface, "icon-theme", value]);
        } else {
            // Hyprland draws its own pointer and exports XCURSOR_* to whatever it launches next; gsettings covers the GTK apps already running.
            Quickshell.execDetached(["hyprctl", "setcursor", root.cursorTheme, String(root.cursorSize)]);
            Quickshell.execDetached(["gsettings", "set", iface, "cursor-theme", root.cursorTheme]);
            Quickshell.execDetached(["gsettings", "set", iface, "cursor-size", String(root.cursorSize)]);
        }

        if (root.loaded)
            file.setText(root.serialise());
        root.writeXsettings();
    }

    // XWayland apps read the theme from xsettingsd rather than from gsettings. Written whole each time and handed over with a HUP; execs.lua starts xsettingsd on this file at login. The path and the contents reach the shell as arguments, never as part of the script.
    readonly property string xsettingsPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/xsettingsd/xsettingsd.conf"

    // One write at a time, and a change that arrives during one is written again once it finishes: the arrows on a picker set a theme per keypress, and two writers racing on the file could leave the older one on disk.
    function writeXsettings(): void {
        if (xsettingsWriter.running) {
            xsettingsWriter.again = true;
            return;
        }

        const lines = [];
        if (root.usableName(root.gtkTheme))
            lines.push("Net/ThemeName \"" + root.gtkTheme + "\"");
        if (root.usableName(root.iconTheme))
            lines.push("Net/IconThemeName \"" + root.iconTheme + "\"");
        if (root.usableName(root.cursorTheme))
            lines.push("Gtk/CursorThemeName \"" + root.cursorTheme + "\"");
        lines.push("Gtk/CursorThemeSize " + root.cursorSize);

        xsettingsWriter.command = ["sh", "-c", 'mkdir -p "${1%/*}" && printf "%s\\n" "$2" > "$1" && pkill -HUP -x xsettingsd', "qsbar-xsettings", root.xsettingsPath, lines.join("\n")];
        xsettingsWriter.running = true;
    }

    // Sorted and without repeats: the same theme is usually installed in more than one of these folders.
    function collect(text: string, kind: string): var {
        const names = [];
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab < 0 || line.slice(0, tab) !== kind)
                continue;
            const name = line.slice(tab + 1);
            if (root.usableName(name) && names.indexOf(name) === -1)
                names.push(name);
        }
        return names.sort((a, b) => a.localeCompare(b));
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false

        // theme.lua is normally a symlink into a dotfiles checkout, and an atomic write renames a fresh file over the link rather than writing through it.
        atomicWrites: false

        onFileChanged: reload()
        onLoaded: root.parse(file.text())
        onLoadFailed: root.loaded = false
    }

    Process {
        id: xsettingsWriter

        property bool again: false

        // pkill answers 1 when nothing matched, which is xsettingsd not running, so it is started on the file just written; started detached, since as this Process it would hold the writer busy for the rest of the session.
        onExited: exitCode => {
            if (exitCode === 1)
                Quickshell.execDetached(["xsettingsd", "-c", root.xsettingsPath]);
            if (xsettingsWriter.again) {
                xsettingsWriter.again = false;
                Qt.callLater(root.writeXsettings);
            }
        }
    }

    Process {
        id: gtkRead

        command: ["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"]

        stdout: StdioCollector {
            onStreamFinished: root.liveGtkTheme = this.text.trim().replace(/^'|'$/g, "")
        }
    }

    // A cursor theme is a folder with cursors/ in it, an icon theme one whose index.theme lists icon directories (some themes are both), and a GTK theme one with gtk-3.0 or gtk-4.0 in it; looked for in every XDG data dir plus the two legacy dot folders.
    Process {
        id: scan

        command: ["sh", "-c", `
            icons() {
                for dir in "$1"/*/; do
                    name=\${dir%/}
                    name=\${name##*/}
                    [ -d "$dir/cursors" ] && printf 'cursor\\t%s\\n' "$name"
                    grep -qs '^Directories=' "$dir/index.theme" && printf 'icon\\t%s\\n' "$name"
                done
            }
            themes() {
                for dir in "$1"/*/; do
                    name=\${dir%/}
                    { [ -d "$dir/gtk-3.0" ] || [ -d "$dir/gtk-4.0" ]; } && printf 'gtk\\t%s\\n' "\${name##*/}"
                done
            }
            icons "$HOME/.icons"
            themes "$HOME/.themes"
            IFS=:
            for base in "\${XDG_DATA_HOME:-$HOME/.local/share}" \${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
                icons "$base/icons"
                themes "$base/themes"
            done
            true
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                root.cursorThemes = root.collect(this.text, "cursor");
                root.iconThemes = root.collect(this.text, "icon");
                root.gtkThemes = root.collect(this.text, "gtk");
            }
        }
    }
}
