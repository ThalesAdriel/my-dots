pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// The GTK, icon and cursor themes, the fonts and text scale, light or dark, the apps' accent and the Flatpak override. hypr/hyprland/theme.lua is where they live.
Singleton {
    id: root

    readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hyprland/theme.lua"

    // Whatever theme.lua returns, key to string or number.
    property var values: ({})

    // False until theme.lua has been read.
    property bool loaded: false

    // What gsettings says the session is using, key to value, for everything theme.lua does not name yet.
    property var live: ({})

    property var gtkThemes: []
    property var iconThemes: []
    property var cursorThemes: []
    property var fontFamilies: []
    property var monoFamilies: []

    readonly property string gtkTheme: root.values.gtk_theme !== undefined ? root.values.gtk_theme : (root.live["gtk-theme"] || "")
    readonly property string iconTheme: root.values.icon_theme !== undefined ? root.values.icon_theme : ""
    readonly property string cursorTheme: root.values.cursor_theme !== undefined ? root.values.cursor_theme : ""
    readonly property int cursorSize: root.values.cursor_size !== undefined ? root.values.cursor_size : 24

    readonly property var cursorSizes: [16, 20, 24, 32, 40, 48, 64]

    readonly property string colorScheme: root.oneOf(root.values.color_scheme !== undefined ? root.values.color_scheme : root.live["color-scheme"], ["default", "prefer-dark", "prefer-light"], "default")
    readonly property string fontName: root.values.font_name !== undefined ? root.values.font_name : (root.live["font-name"] || "")
    readonly property string monospaceFontName: root.values.monospace_font_name !== undefined ? root.values.monospace_font_name : (root.live["monospace-font-name"] || "")
    readonly property string fontAntialiasing: root.oneOf(root.values.font_antialiasing !== undefined ? root.values.font_antialiasing : root.live["font-antialiasing"], ["none", "grayscale", "rgba"], "grayscale")
    readonly property string fontHinting: root.oneOf(root.values.font_hinting !== undefined ? root.values.font_hinting : root.live["font-hinting"], ["none", "slight", "medium", "full"], "slight")
    readonly property real textScale: {
        const value = Number(root.values.text_scaling_factor !== undefined ? root.values.text_scaling_factor : root.live["text-scaling-factor"]);
        return value >= 0.5 && value <= 3 ? value : 1;
    }

    // The accent follows the bar's and Flatpak apps are left alone, unless theme.lua says otherwise.
    readonly property bool accentFromBar: root.values.accent_from_bar !== 0
    readonly property bool flatpakTheme: root.values.flatpak_theme === 1

    // theme.lua keeps a name: the layouts themselves have characters execs.lua could not splice safely.
    readonly property var buttonLayouts: ({
            close: "appmenu:close",
            all: "appmenu:minimize,maximize,close",
            none: "appmenu:"
        })
    readonly property string titleButtons: {
        if (root.values.title_buttons !== undefined)
            return root.oneOf(root.values.title_buttons, Object.keys(root.buttonLayouts), "close");
        return Object.keys(root.buttonLayouts).find(name => root.buttonLayouts[name] === root.live["button-layout"]) || "";
    }

    // The gsettings key each theme.lua key sets in org.gnome.desktop.interface.
    readonly property var interfaceKeys: ({
            gtk_theme: "gtk-theme",
            icon_theme: "icon-theme",
            color_scheme: "color-scheme",
            accent_color: "accent-color",
            font_name: "font-name",
            monospace_font_name: "monospace-font-name",
            font_antialiasing: "font-antialiasing",
            font_hinting: "font-hinting",
            text_scaling_factor: "text-scaling-factor"
        })

    // libadwaita's accents, which are names rather than colours, and the colour each one is.
    readonly property var accents: ({
            blue: "#3584e4",
            teal: "#2190a4",
            green: "#3a944a",
            yellow: "#c88800",
            orange: "#ed5b00",
            red: "#e62d42",
            pink: "#d56199",
            purple: "#9141ac",
            slate: "#6f8396"
        })

    function oneOf(value: var, allowed: var, fallback: string): string {
        return allowed.indexOf(value) !== -1 ? value : fallback;
    }

    // A gsettings font name is the family and the size in points, "Inter 11".
    function familyOf(name: string): string {
        const match = /^(.*\S)\s+\d+(?:\.\d+)?$/.exec(name);
        return match ? match[1] : name;
    }

    function sizeOf(name: string, fallback: int): int {
        const match = /\s(\d+)(?:\.\d+)?$/.exec(name);
        return match ? Number(match[1]) : fallback;
    }

    // The accent nearest the bar's colour, by plain distance in RGB.
    function nearestAccent(colour: string): string {
        let target;
        try {
            target = Qt.color(colour);
        } catch (error) {
            return "blue";
        }
        let best = "blue";
        let bestDistance = Infinity;
        for (const name of Object.keys(root.accents)) {
            const candidate = Qt.color(root.accents[name]);
            const dr = candidate.r - target.r;
            const dg = candidate.g - target.g;
            const db = candidate.b - target.b;
            const distance = dr * dr + dg * dg + db * db;
            if (distance < bestDistance) {
                best = name;
                bestDistance = distance;
            }
        }
        return best;
    }

    // Only once theme.lua has been read, which calls this itself.
    function followAccent(): void {
        if (!root.loaded || !root.accentFromBar)
            return;
        const name = root.nearestAccent(Settings.accentColor);
        if (root.values.accent_color !== name)
            root.set("accent_color", name);
    }

    // Flatpak apps see neither the host's GTK theme setting nor its theme folders.
    function applyFlatpak(): void {
        if (!root.flatpakTheme)
            Quickshell.execDetached(["flatpak", "override", "--user", "--unset-env=GTK_THEME"]);
        else if (root.usableName(root.gtkTheme))
            Quickshell.execDetached(["flatpak", "override", "--user", "--filesystem=xdg-data/themes:ro", "--filesystem=~/.themes:ro", "--env=GTK_THEME=" + root.gtkTheme]);
    }

    function readLive(text: string): void {
        const next = {};
        for (const line of text.split("\n")) {
            const match = /^\S+ (\S+) (.*)$/.exec(line);
            if (match)
                next[match[1]] = match[2].replace(/^'|'$/g, "");
        }
        root.live = next;
    }

    // execs.lua splices these into a shell line at login.
    function usableName(name: string): bool {
        return /^[A-Za-z0-9][A-Za-z0-9 _.+@-]*$/.test(name);
    }

    function refresh(): void {
        if (!scan.running)
            scan.running = true;
        if (!liveRead.running)
            liveRead.running = true;
    }

    function parse(text: string): void {
        const next = {};
        const pattern = /(\w+)\s*=\s*(?:"([^"\\\n]*)"|(-?\d+(?:\.\d+)?))/g;
        let match;
        while ((match = pattern.exec(text)) !== null)
            next[match[1]] = match[2] !== undefined ? match[2] : Number(match[3]);

        root.values = next;
        root.loaded = true;
        root.followAccent();
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
        if (key === "cursor_theme" || key === "cursor_size") {
            // Hyprland draws its own pointer; gsettings covers the GTK apps already running.
            root.applyCursor();
            Quickshell.execDetached(["gsettings", "set", iface, "cursor-theme", root.cursorTheme]);
            Quickshell.execDetached(["gsettings", "set", iface, "cursor-size", String(root.cursorSize)]);
        } else if (Object.prototype.hasOwnProperty.call(root.interfaceKeys, key)) {
            // A double for gsettings wants its decimal point: "1" is read as an integer and refused.
            Quickshell.execDetached(["gsettings", "set", iface, root.interfaceKeys[key], key === "text_scaling_factor" ? Number(value).toFixed(2) : String(value)]);
        } else if (key === "title_buttons" && root.titleButtons !== "") {
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.wm.preferences", "button-layout", root.buttonLayouts[root.titleButtons]]);
        }

        if (key === "accent_from_bar")
            root.followAccent();
        if (key === "flatpak_theme" || (key === "gtk_theme" && root.flatpakTheme))
            root.applyFlatpak();

        if (root.loaded)
            file.setText(root.serialise());
        root.writeXsettings();
    }

    // What Hyprland said to the last setcursor when it was not "ok", shown on the theme page.
    property string cursorError: ""

    // One call at a time, with a change that arrives during one sent again once it finishes, like the xsettingsd writer below.
    function applyCursor(): void {
        if (cursorApply.running) {
            cursorApply.again = true;
            return;
        }
        cursorApply.command = ["hyprctl", "setcursor", root.cursorTheme, String(root.cursorSize)];
        cursorApply.running = true;
    }

    // XWayland apps read the theme from xsettingsd rather than from gsettings.
    readonly property string xsettingsPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/xsettingsd/xsettingsd.conf"

    // One write at a time, and a change that arrives during one is written again once it finishes.
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
        if (root.usableName(root.fontName))
            lines.push("Gtk/FontName \"" + root.fontName + "\"");
        lines.push("Xft/Antialias " + (root.fontAntialiasing === "none" ? 0 : 1));
        lines.push("Xft/RGBA \"" + (root.fontAntialiasing === "rgba" ? "rgb" : "none") + "\"");
        lines.push("Xft/Hinting " + (root.fontHinting === "none" ? 0 : 1));
        lines.push("Xft/HintStyle \"hint" + root.fontHinting + "\"");
        // X11 apps take the text scale as a DPI, in 1024ths of a dot per inch.
        lines.push("Xft/DPI " + Math.round(96 * 1024 * root.textScale));
        if (root.titleButtons !== "")
            lines.push("Gtk/DecorationLayout \"" + root.buttonLayouts[root.titleButtons] + "\"");

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

    Connections {
        target: Settings

        function onAccentColorChanged(): void {
            root.followAccent();
        }
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false

        // theme.lua is normally a symlink into a dotfiles checkout.
        atomicWrites: false

        onFileChanged: reload()
        onLoaded: root.parse(file.text())
        onLoadFailed: root.loaded = false
    }

    Process {
        id: cursorApply

        property bool again: false

        stdout: StdioCollector {
            onStreamFinished: {
                const reply = this.text.trim();
                root.cursorError = reply === "" || reply === "ok" ? "" : reply.split("\n")[0];
            }
        }

        // Where hyprctl says it could not reach Hyprland at all.
        stderr: StdioCollector {
            onStreamFinished: {
                const message = this.text.trim();
                if (message !== "")
                    root.cursorError = message.split("\n")[0];
            }
        }

        onExited: {
            if (cursorApply.again) {
                cursorApply.again = false;
                Qt.callLater(root.applyCursor);
            }
        }
    }

    Process {
        id: xsettingsWriter

        property bool again: false

        // pkill answers 1 when nothing matched.
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
        id: liveRead

        command: ["sh", "-c", "gsettings list-recursively org.gnome.desktop.interface; gsettings list-recursively org.gnome.desktop.wm.preferences"]

        stdout: StdioCollector {
            onStreamFinished: root.readLive(this.text)
        }
    }

    // A cursor theme is a folder with cursors/ in it, an icon theme one whose index.theme lists icon directories (some themes are both).
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
            fonts() {
                fc-list "$1" family 2>/dev/null | while IFS= read -r family; do
                    printf '%s\\t%s\\n' "$2" "\${family%%,*}"
                done
            }
            fonts : font
            fonts :spacing=mono mono
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
                root.fontFamilies = root.collect(this.text, "font");
                root.monoFamilies = root.collect(this.text, "mono");
            }
        }
    }
}
