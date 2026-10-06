pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd

Singleton {
    id: root

    // Where qsbar writes the settings and copies the two pictures.
    readonly property string dir: Quickshell.env("QUICKGREET_DIR") || "/var/lib/quickgreet"

    // Outside greetd there is nothing to log in to, so it is a preview.
    readonly property bool preview: !Greetd.available

    // The stamp is bumped by qsbar on every copy.
    readonly property string wallpaper: settings.background === "image" && settings.wallpaper !== "" ? "file://" + root.dir + "/wallpaper?" + settings.stamp : ""
    readonly property string avatar: settings.avatar !== "" ? "file://" + root.dir + "/avatar?" + settings.stamp : ""
    readonly property color backgroundColor: settings.background === "color" ? root.colour(settings.color, "#1b1b1b") : "#000000"

    readonly property real dim: settings.dim
    readonly property int blurRadius: settings.blur

    readonly property string animation: settings.animation
    readonly property real animationOpacity: settings.animationOpacity
    readonly property int animationSpeed: Math.max(10, settings.animationSpeed)
    readonly property int cellSize: 14

    readonly property string border: settings.border
    readonly property int rounding: settings.rounding

    // On top of following the screen's height, which Surface does.
    readonly property real uiScale: Math.max(0.5, Math.min(2, settings.scale))

    function radius(value, size) {
        return Math.max(0, Math.min(value, size / 2));
    }

    // Some of sysc-greet's themes.
    readonly property var themes: ({
            dracula: {
                bg: "#282a36",
                active: "#44475a",
                primary: "#bd93f9",
                secondary: "#8be9fd",
                accent: "#50fa7b",
                warning: "#f1fa8c",
                danger: "#ff5555",
                fg: "#f8f8f2",
                muted: "#6272a4"
            },
            catppuccin: {
                bg: "#1e1e2e",
                active: "#313244",
                primary: "#cba6f7",
                secondary: "#89b4fa",
                accent: "#a6e3a1",
                warning: "#f9e2af",
                danger: "#f38ba8",
                fg: "#cdd6f4",
                muted: "#a6adc8"
            },
            nord: {
                bg: "#2e3440",
                active: "#3b4252",
                primary: "#81a1c1",
                secondary: "#88c0d0",
                accent: "#8fbcbb",
                warning: "#ebcb8b",
                danger: "#bf616a",
                fg: "#eceff4",
                muted: "#d8dee9"
            },
            "tokyo-night": {
                bg: "#1a1b26",
                active: "#24283b",
                primary: "#7aa2f7",
                secondary: "#bb9af7",
                accent: "#9ece6a",
                warning: "#e0af68",
                danger: "#f7768e",
                fg: "#c0caf5",
                muted: "#565f89"
            },
            gruvbox: {
                bg: "#282828",
                active: "#3c3836",
                primary: "#fe8019",
                secondary: "#8ec07c",
                accent: "#fabd2f",
                warning: "#d79921",
                danger: "#cc241d",
                fg: "#ebdbb2",
                muted: "#bdae93"
            },
            solarized: {
                bg: "#002b36",
                active: "#073642",
                primary: "#268bd2",
                secondary: "#2aa198",
                accent: "#859900",
                warning: "#b58900",
                danger: "#dc322f",
                fg: "#fdf6e3",
                muted: "#93a1a1"
            },
            monochrome: {
                bg: "#1a1a1a",
                active: "#2a2a2a",
                primary: "#ffffff",
                secondary: "#cccccc",
                accent: "#888888",
                warning: "#aaaaaa",
                danger: "#999999",
                fg: "#ffffff",
                muted: "#666666"
            }
        })

    // The file is written by a user and read by the greeter.
    function entry(table, name) {
        return Object.prototype.hasOwnProperty.call(table, name) ? table[name] : null;
    }

    // Likewise a colour is only taken in the hex qsbar writes, else the default.
    function colour(value, fallback) {
        return /^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(value) ? value : fallback;
    }

    // The system theme is qsbar's own look.
    readonly property var systemTheme: {
        const surface = root.colour(settings.surface, "#000000");
        const accent = root.colour(settings.accent, "#e01b24");
        return {
            bg: surface,
            active: Qt.tint(surface, Qt.rgba(1, 1, 1, 0.08)),
            primary: accent,
            secondary: root.mix(accent, "#ffffff", 0.35),
            accent: accent,
            warning: "#cc8822",
            danger: "#e01b24",
            fg: "#ffffff",
            muted: "#8c8c8c"
        };
    }

    readonly property var theme: root.entry(root.themes, settings.theme) || root.systemTheme

    function alpha(value, amount) {
        const c = Qt.color(value);
        return Qt.rgba(c.r, c.g, c.b, amount);
    }

    function mix(from, to, amount) {
        const a = Qt.color(from);
        const b = Qt.color(to);
        return Qt.rgba(a.r + (b.r - a.r) * amount, a.g + (b.g - a.g) * amount, a.b + (b.b - a.b) * amount, 1);
    }

    readonly property color card: root.alpha(root.theme.active, 0.62)
    readonly property color field: root.alpha(root.theme.bg, 0.7)
    readonly property color hover: root.alpha(root.theme.fg, 0.1)
    readonly property color text: root.theme.fg
    readonly property color muted: root.theme.muted
    readonly property color focus: root.alpha(root.theme.primary, 0.55)
    readonly property color line: root.theme.primary
    readonly property color caps: root.theme.accent
    readonly property color fail: root.theme.danger
    readonly property color check: root.theme.warning

    // Six levels, dimmest to brightest: the six colours the animation layer draws in.
    readonly property var ramp: [root.mix(root.theme.bg, root.theme.secondary, 0.45), root.theme.secondary, root.mix(root.theme.secondary, root.theme.primary, 0.5), root.theme.primary, root.theme.accent, root.theme.fg]

    // Asked once: enumerating the installed fonts is not cheap.
    readonly property var families: Qt.fontFamilies()

    function pick(candidates) {
        for (const family of candidates) {
            if (root.families.indexOf(family) !== -1)
                return family;
        }
        return candidates[candidates.length - 1];
    }

    readonly property string fontFamily: root.pick(["Rubik", "Inter", "Noto Sans", "Cantarell", "DejaVu Sans"])

    // The Mono variant of a Nerd Font keeps every glyph one cell wide.
    readonly property string monoFamily: root.pick(["JetBrainsMono Nerd Font Mono", "JetBrains Mono", "DejaVu Sans Mono", "Noto Sans Mono", "monospace"])
    readonly property string iconFamily: root.pick(["Font Awesome 7 Free Solid", "Font Awesome 6 Free Solid", "Font Awesome 7 Free", "Font Awesome 6 Free", "Font Awesome 5 Free"])

    // The mockup, measured at 1080p.
    readonly property int cardWidth: 462
    readonly property int cardHeight: 305
    readonly property int avatarSize: 112
    readonly property int fieldWidth: 300
    readonly property int fieldHeight: 42
    readonly property int submitWidth: 70
    readonly property int cornerSize: 60
    readonly property int menuWidth: 230
    readonly property int textSize: 15
    readonly property int outlineThickness: 2
    readonly property int dotSize: Math.round(root.fieldHeight * 0.2 / 2) * 2
    readonly property int dotSpacing: Math.floor(root.dotSize * 0.3)

    readonly property int animFast: 100
    readonly property int animNormal: 200

    FileView {
        id: file

        path: root.dir + "/quickgreet.json"
        blockLoading: true
        printErrors: false
        watchChanges: true

        onFileChanged: file.reload()

        // Mirrored in qsbar/services/GreetConfig.qml, which writes this file; a key added here goes there too.
        adapter: JsonAdapter {
            id: settings

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
}
