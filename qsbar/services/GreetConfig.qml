pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// quickgreet's settings file, edited from here.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/home"
    readonly property string dir: Quickshell.env("QUICKGREET_DIR") || "/var/lib/quickgreet"

    property alias background: adapter.background
    property alias color: adapter.color
    readonly property string wallpaper: adapter.wallpaper
    readonly property string avatar: adapter.avatar
    property alias dim: adapter.dim
    property alias blur: adapter.blur
    property alias theme: adapter.theme
    property alias animation: adapter.animation
    property alias animationOpacity: adapter.animationOpacity
    property alias animationSpeed: adapter.animationSpeed
    property alias border: adapter.border
    property alias rounding: adapter.rounding
    property alias uiScale: adapter.scale

    // Not installed yet: there is no file, and nowhere to write one.
    property bool missing: false

    // The file is there but did not parse.
    property bool broken: false

    property string lastError: ""

    readonly property var themes: ["system", "dracula", "catppuccin", "nord", "tokyo-night", "gruvbox", "solarized", "monochrome"]
    readonly property var animations: ["none", "matrix", "rain", "fireworks", "aquarium", "spiral"]

    // From nothing at all, through the two bars of the mockup, to a whole frame and the plainer characters it can be drawn in.
    readonly property var borders: ["none", "brackets", "corners", "dashed", "rounded", "double", "ascii"]

    readonly property var labels: ({
            "system": "System (accent colour)",
            "tokyo-night": "Tokyo Night",
            "ascii": "ASCII"
        })

    // What the pickers show for a value: its own label, or the name with its first letter up.
    function label(value: string): string {
        return root.labels[value] || value.charAt(0).toUpperCase() + value.slice(1);
    }

    // The system theme is drawn in qsbar's surface and accent colours.
    function syncColours(): void {
        if (root.missing || root.broken)
            return;
        if (adapter.accent !== Settings.accentColor)
            adapter.accent = Settings.accentColor;
        if (adapter.surface !== Settings.surfaceColor)
            adapter.surface = Settings.surfaceColor;
    }

    Connections {
        target: Settings

        function onAccentColorChanged(): void {
            root.syncColours();
        }

        function onSurfaceColorChanged(): void {
            root.syncColours();
        }
    }

    // The same rules quicklock's settings follow.
    function expand(value: string): string {
        if (!value)
            return "";
        const path = value.startsWith("file://") ? value.slice(7) : value;
        const full = path.startsWith("~/") ? root.home + path.slice(1) : path;
        return full.startsWith("/") ? full : "";
    }

    // A picture for the greeter.
    function setPicture(kind: string, path: string): void {
        root.lastError = "";
        const copier = kind === "avatar" ? avatarCopy : wallpaperCopy;
        if (path.trim() === "") {
            copier.start("", kind, "");
            return;
        }
        const source = root.expand(path.trim());
        if (source === "") {
            root.lastError = "Not a path: " + path;
            return;
        }
        copier.start(source, kind, path.trim());
    }

    // The greeter as it will look, over everything, until Esc or a power button.
    function test(): void {
        root.lastError = "";
        UiState.settingsOpen = false;
        tester.running = false;
        tester.running = true;
    }

    function restoreDefaults(): void {
        root.lastError = "";
        adapter.background = "image";
        adapter.color = "#1b1b1b";
        adapter.dim = 0.34;
        adapter.blur = 56;
        adapter.theme = "system";
        adapter.animation = "none";
        adapter.animationOpacity = 0.5;
        adapter.animationSpeed = 100;
        adapter.border = "brackets";
        adapter.rounding = 0;
        adapter.scale = 1;
        root.setPicture("wallpaper", "");
        root.setPicture("avatar", "");
    }

    // One per picture, so picking the wallpaper and then the avatar in quick succession does not cut the first copy short.
    component Copier: Process {
        id: copier

        property string kind: ""
        property string path: ""

        function start(source: string, kind: string, path: string): void {
            copier.running = false;
            copier.kind = kind;
            copier.path = path;
            const target = root.dir + "/" + kind;
            copier.command = source === "" ? ["rm", "-f", "--", target] : ["sh", "-c", "cp -f -- \"$1\" \"$2.tmp\" && chmod 644 \"$2.tmp\" && mv -f -- \"$2.tmp\" \"$2\"", "qsbar-greet", source, target];
            copier.running = true;
        }

        stderr: StdioCollector {
            id: copyErrors
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.lastError = copyErrors.text.trim().split("\n")[0] || "Could not copy the picture into " + root.dir;
                return;
            }
            adapter[copier.kind] = copier.path;
            adapter.stamp = Date.now();
        }
    }

    Copier {
        id: wallpaperCopy
    }

    Copier {
        id: avatarCopy
    }

    Process {
        id: tester

        command: ["sh", "-c", "for q in /usr/share/quickgreet/quickgreet \"${XDG_CONFIG_HOME:-$HOME/.config}/quickgreet/quickgreet\"; do [ -x \"$q\" ] && exec \"$q\"; done; exit 127"]

        onExited: exitCode => {
            if (exitCode === 127)
                root.lastError = "quickgreet is not installed: run ./install.sh config from the dotfiles";
        }
    }

    FileView {
        id: file

        path: root.dir + "/quickgreet.json"
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            root.broken = false;
            root.missing = false;
            root.syncColours();
        }
        onLoadFailed: error => {
            root.missing = error === FileViewError.FileNotFound;
            root.broken = !root.missing;
        }

        // Debounced like Settings: a slider hands over a value per mouse move.
        onAdapterUpdated: writeTimer.restart()

        JsonAdapter {
            id: adapter

            property string background: "image"
            property string color: "#1b1b1b"
            property string wallpaper: ""
            property string avatar: ""
            property real stamp: 0
            property real dim: 0.34
            property int blur: 56
            property string theme: "system"
            property string accent: "#e01b24"
            property string surface: "#000000"
            property string animation: "none"
            property real animationOpacity: 0.5
            property int animationSpeed: 100
            property string border: "brackets"
            property int rounding: 0
            property real scale: 1
        }
    }

    Timer {
        id: writeTimer

        interval: 400
        onTriggered: {
            if (!root.broken && !root.missing)
                file.writeAdapter();
        }
    }
}
