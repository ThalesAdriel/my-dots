pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// quicklock's own config file, edited from here. quicklock watches the file, so a change lands on the lock screen without restarting anything; the properties and their defaults mirror quicklock/config/Config.qml and have to move with it.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/home"
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (root.home + "/.config")) + "/quicklock"

    property alias wallpaper: adapter.wallpaper
    property alias avatar: adapter.avatar
    readonly property string pam: adapter.pam
    property alias timeFormat: adapter.timeFormat
    property alias dateFormat: adapter.dateFormat
    property alias dim: adapter.dim
    property alias blur: adapter.blur
    property alias contrast: adapter.contrast
    property alias vibrancy: adapter.vibrancy
    property alias avatarSize: adapter.avatarSize
    property alias avatarOffset: adapter.avatarOffset
    property alias rounding: adapter.rounding
    property alias dotRounding: adapter.dotRounding
    property alias avatarRounding: adapter.avatarRounding
    property alias iconFont: adapter.iconFont
    property alias caffeineIcon: adapter.caffeineIcon
    property alias caffeine: adapter.caffeine

    // The file is there but did not parse. Nothing is written back while this is set: saving would replace a file somebody is halfway through editing by hand with the defaults.
    property bool broken: false

    property string pamError: ""
    property string pendingPam: ""

    // The same rules quicklock applies when it reads the file: ~/ is home, a file:// prefix is dropped, and anything left that is not absolute is ignored.
    function expand(value: string): string {
        if (!value)
            return "";
        const path = value.startsWith("file://") ? value.slice(7) : value;
        const full = path.startsWith("~/") ? root.home + path.slice(1) : path;
        return full.startsWith("/") ? full : "";
    }

    // Back to quicklock's own defaults, the ones in the adapter below. An empty wallpaper and avatar are not blanks: quicklock falls back to ~/Pictures/wallpapers/w.jpg and ~/.face on its own.
    function restoreDefaults(): void {
        root.pamError = "";
        adapter.wallpaper = "";
        adapter.avatar = "";
        adapter.pam = "login";
        adapter.timeFormat = "HH:mm";
        adapter.dateFormat = "dddd, MMMM dd";
        adapter.dim = 0.34;
        adapter.blur = 56;
        adapter.contrast = -0.11;
        adapter.vibrancy = 0.17;
        adapter.avatarSize = 110;
        adapter.avatarOffset = 130;
        adapter.rounding = 0;
        adapter.dotRounding = -1;
        adapter.avatarRounding = -1;
        adapter.iconFont = "Font Awesome 7 Free";
        adapter.caffeineIcon = "";
        adapter.caffeine = true;
    }

    // A wrong service name here is a lock screen nothing can unlock: PAM falls back to "other", which refuses everyone, and the way out is another TTY. So a name only reaches the file once /etc/pam.d has a file by that name.
    function setPam(name: string): void {
        root.pamError = "";
        if (name === adapter.pam)
            return;
        if (!/^[A-Za-z0-9_.-]+$/.test(name)) {
            root.pamError = "Not a PAM service name";
            return;
        }

        root.pendingPam = name;
        pamCheck.command = ["test", "-f", "/etc/pam.d/" + name];
        pamCheck.running = true;
    }

    FileView {
        id: file

        path: root.dir + "/quicklock.json"
        watchChanges: true
        printErrors: false

        // Usually a symlink into a dotfiles checkout, and an atomic write renames a fresh file over the link rather than writing through it.
        atomicWrites: false

        onFileChanged: reload()
        onLoaded: root.broken = false
        onLoadFailed: error => root.broken = error !== FileViewError.FileNotFound

        // Debounced like Settings: a slider hands over a value per mouse move.
        onAdapterUpdated: writeTimer.restart()

        JsonAdapter {
            id: adapter

            property string wallpaper: ""
            property string avatar: ""
            property string pam: "login"
            property string timeFormat: "HH:mm"
            property string dateFormat: "dddd, MMMM dd"
            property real dim: 0.34
            property int blur: 56
            property real contrast: -0.11
            property real vibrancy: 0.17
            property int avatarSize: 110
            property int avatarOffset: 130
            property int rounding: 0
            property int dotRounding: -1
            property int avatarRounding: -1
            property string iconFont: "Font Awesome 7 Free"
            property string caffeineIcon: ""
            property bool caffeine: true
        }
    }

    Timer {
        id: writeTimer

        interval: 400
        onTriggered: {
            if (!root.broken)
                file.writeAdapter();
        }
    }

    Process {
        id: pamCheck

        onExited: exitCode => {
            if (exitCode === 0)
                adapter.pam = root.pendingPam;
            else
                root.pamError = "/etc/pam.d/" + root.pendingPam + " does not exist";
        }
    }
}
