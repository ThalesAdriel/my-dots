pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/home"
    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/quicklock"

    function expand(value) {
        if (!value || value.length === 0)
            return "";
        const path = value.startsWith("file://") ? value.slice(7) : value;
        const full = path.startsWith("~/") ? root.home + path.slice(1) : path;
        return full.startsWith("/") ? full : "";
    }

    function push(list, value) {
        const url = root.expand(value);
        if (url.length > 0 && list.indexOf(url) === -1)
            list.push(url);
    }

    readonly property var wallpaperPaths: {
        const list = [];
        root.push(list, Quickshell.env("QUICKLOCK_WALLPAPER"));
        root.push(list, settings.wallpaper);
        root.push(list, root.dir + "/wallpaper");
        root.push(list, root.home + "/Pictures/wallpapers/w.jpg");
        return list;
    }

    readonly property var avatarPaths: {
        const list = [];
        root.push(list, Quickshell.env("QUICKLOCK_AVATAR"));
        root.push(list, settings.avatar);
        root.push(list, root.dir + "/avatar");
        root.push(list, root.dir + "/avatar.png");
        root.push(list, root.dir + "/avatar.jpg");
        root.push(list, root.home + "/.face");
        root.push(list, root.home + "/.face.icon");
        root.push(list, "/var/lib/AccountsService/icons/" + root.user);
        return list;
    }

    readonly property string wallpaper: wallpaperPick.result.length > 0 ? "file://" + wallpaperPick.result : ""
    readonly property string avatar: avatarPick.result.length > 0 ? "file://" + avatarPick.result : ""

    readonly property string pamConfig: Quickshell.env("QUICKLOCK_PAM") || settings.pam || "login"

    readonly property color background: "#181818"
    readonly property color text: "#d7e4ef"
    readonly property color entryBackground: "#11111d25"
    readonly property color entryBorder: "#55919091"
    readonly property color entryText: "#d7e4ef"
    readonly property color capsColor: "#f2b8b5"
    readonly property color failColor: "#cc2222"
    readonly property color checkColor: "#cc8822"

    readonly property string fontFamily: "Rubik"
    readonly property string fontFamilyClock: "Space Grotesk"
    readonly property string fontFamilySymbols: "Material Symbols Rounded"
    readonly property string fontFamilyIcons: settings.iconFont

    readonly property int clockSize: 65
    readonly property int dateSize: 17
    readonly property int userSize: 20
    readonly property int statusSize: 14
    readonly property int caffeineSize: 18

    readonly property string timeFormat: settings.timeFormat
    readonly property string dateFormat: settings.dateFormat

    // Qt reads anything between single quotes as literal text, so with those cut away what is left is format characters alone: an s among them is a seconds field and not somebody's word. An unterminated quote leaves its tail in, which at worst ticks a clock faster than it needed to.
    function showsSeconds(format) {
        return format.replace(/'[^']*'/g, "").indexOf("s") !== -1;
    }

    // What the clock has to tick at. Either format can ask for seconds, and until now neither got them: the tick was a minute whatever the file said, so "HH:mm:ss" sat there frozen.
    readonly property bool secondsVisible: root.showsSeconds(root.timeFormat) || root.showsSeconds(root.dateFormat)

    readonly property int clockOffset: 300
    readonly property int dateOffset: 240
    readonly property int fieldOffset: 20
    readonly property int userOffset: 50
    readonly property int userGap: 14
    readonly property int statusMarginX: 30
    readonly property int statusMarginY: 30

    readonly property int fieldWidth: 250
    readonly property int fieldHeight: 50
    readonly property int outlineThickness: 2
    readonly property int dotSize: Math.round(root.fieldHeight * 0.2 / 2) * 2
    readonly property int dotSpacing: Math.floor(root.dotSize * 0.3)
    readonly property int hintSize: Math.round(root.fieldHeight * 0.3)

    readonly property int rounding: settings.rounding
    readonly property int dotRounding: settings.dotRounding
    readonly property int avatarRounding: settings.avatarRounding

    function radius(value, size) {
        if (value < 0)
            return size / 2;
        return Math.min(value, size / 2);
    }

    readonly property string placeholderText: "<i>Input Password...</i>"
    readonly property string failPrefix: "Authentication failed"

    readonly property string caffeineIcon: settings.caffeineIcon
    readonly property bool caffeineDefault: settings.caffeine

    readonly property bool fadeOnEmpty: true
    readonly property int fadeTimeout: 2000
    readonly property int fadeDuration: 180

    readonly property int avatarSize: settings.avatarSize
    readonly property int avatarOffset: settings.avatarOffset
    readonly property int avatarRing: 2

    readonly property real dim: settings.dim
    readonly property int blurRadius: settings.blur
    readonly property real contrast: settings.contrast
    readonly property real vibrancy: settings.vibrancy
    readonly property int downscale: 2

    readonly property int animFast: 100
    readonly property int animNormal: 200

    PathPicker {
        id: wallpaperPick
        candidates: root.wallpaperPaths
    }

    PathPicker {
        id: avatarPick
        candidates: root.avatarPaths
    }

    FileView {
        id: file

        path: root.dir + "/quicklock.json"
        blockLoading: true
        printErrors: false
        watchChanges: true

        onFileChanged: file.reload()

        adapter: JsonAdapter {
            id: settings

            property string wallpaper: ""
            property string avatar: ""
            property string pam: "login"
            property string timeFormat: "HH:mm"
            property string dateFormat: "dddd, MMMM dd"
            property real dim: 0.34
            property int blur: 56
            property real contrast: -0.11
            property real vibrancy: 0.17
            property int avatarSize: 82
            property int avatarOffset: 130
            property int rounding: 0
            property int dotRounding: 0
            property int avatarRounding: 0
            property string iconFont: "Font Awesome 7 Free"
            property string caffeineIcon: "\uf0f4"
            property bool caffeine: true
        }
    }
}
