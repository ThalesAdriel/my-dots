pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property alias barColor: adapter.barColor
    property alias barOpacity: adapter.barOpacity
    property alias barRadius: adapter.barRadius
    property alias barHeight: adapter.barHeight
    property alias outerCorners: adapter.outerCorners
    property alias outerCornerRadius: adapter.outerCornerRadius
    property alias barBlur: adapter.barBlur
    property alias panelRadius: adapter.panelRadius
    property alias surfaceColor: adapter.surfaceColor
    property alias panelOpacity: adapter.panelOpacity
    property alias panelBlur: adapter.panelBlur

    property alias hoverOpacity: adapter.hoverOpacity
    property alias hoverRadius: adapter.hoverRadius
    property alias accentColor: adapter.accentColor

    property alias iconSize: adapter.iconSize
    property alias iconPadding: adapter.iconPadding
    property alias moduleSpacing: adapter.moduleSpacing
    property alias workspaceSpacing: adapter.workspaceSpacing

    // The four bar modules that stay off until asked for: each costs a polled process while it is on.
    property alias showNetwork: adapter.showNetwork
    property alias showBluetooth: adapter.showBluetooth
    property alias showBattery: adapter.showBattery
    property alias showRecording: adapter.showRecording

    // The saved monitor arrangement, keyed by connector.
    property alias displayLayout: adapter.displayLayout

    // Where the brightness slider was left on a machine with no backlight to read back from.
    property alias gammaBrightness: adapter.gammaBrightness

    // Where a toast is drawn: "integrated" hangs it off the bar, "floating" is the detached card.
    property alias notificationStyle: adapter.notificationStyle

    // How wide a toast is drawn, and how long one that named no timeout of its own stays.
    property alias notificationWidth: adapter.notificationWidth

    // A floor rather than a fixed height.
    property alias notificationHeight: adapter.notificationHeight
    property alias notificationSeconds: adapter.notificationSeconds

    // Real surface captures in the overview.
    property alias overviewPreviews: adapter.overviewPreviews

    // How awww moves from one desktop wallpaper to the next.
    property alias wallpaperTransition: adapter.wallpaperTransition
    property alias wallpaperTransitionSeconds: adapter.wallpaperTransitionSeconds

    // awww's --resize.
    property alias wallpaperResize: adapter.wallpaperResize

    // The folder both wallpaper grids list, for the desktop and for the lock screen.
    property alias wallpaperFolder: adapter.wallpaperFolder

    // The bar's keep awake button, one state for every screen's bar and kept across restarts.
    property alias keepAwake: adapter.keepAwake

    // Minutes idle before hypridle locks, turns the screens off and suspends, 0 for never.
    property alias idleLockMinutes: adapter.idleLockMinutes
    property alias idleScreenOffMinutes: adapter.idleScreenOffMinutes
    property alias idleSuspendMinutes: adapter.idleSuspendMinutes

    // Hyprland's misc:vrr and render:direct_scanout, which HyprSync writes into hypr/hyprland/gaming.lua.
    property alias vrr: adapter.vrr
    property alias directScanout: adapter.directScanout

    // Set once settings.json has been read, or found missing and written.
    property bool loaded: false

    property alias clockShowSeconds: adapter.clockShowSeconds
    property alias clockUse12Hour: adapter.clockUse12Hour
    property alias clockShowProgress: adapter.clockShowProgress
    property alias calendarYearView: adapter.calendarYearView

    readonly property string clockFormat: {
        const hour = adapter.clockUse12Hour ? "hh" : "HH";
        const suffix = adapter.clockUse12Hour ? " AP" : "";
        return adapter.clockShowSeconds ? hour + ":mm:ss" + suffix : hour + ":mm" + suffix;
    }

    function restoreDefaults(): void {
        adapter.barColor = "#000000";
        adapter.barOpacity = 0.85;
        adapter.barRadius = 0;
        adapter.barHeight = 25;
        adapter.outerCorners = true;
        adapter.outerCornerRadius = 12;
        adapter.barBlur = false;
        adapter.panelRadius = 0;
        adapter.surfaceColor = "#000000";
        adapter.panelOpacity = 0.85;
        adapter.panelBlur = false;
        adapter.hoverOpacity = 0.26;
        adapter.hoverRadius = 0;
        adapter.accentColor = "#e01b24";
        adapter.iconSize = 12;
        adapter.iconPadding = 3;
        adapter.moduleSpacing = 0;
        adapter.workspaceSpacing = 2;
        adapter.showNetwork = false;
        adapter.showBluetooth = false;
        adapter.showBattery = false;
        adapter.showRecording = false;
        adapter.notificationStyle = "integrated";
        adapter.notificationWidth = 380;
        adapter.notificationHeight = 64;
        adapter.notificationSeconds = 10;
        adapter.overviewPreviews = true;
        adapter.wallpaperTransition = "fade";
        adapter.wallpaperTransitionSeconds = 1.2;
        adapter.wallpaperResize = "crop";
        adapter.clockShowSeconds = true;
        adapter.clockUse12Hour = false;
        adapter.clockShowProgress = false;
        adapter.calendarYearView = true;
    }

    FileView {
        id: fileView

        path: Quickshell.statePath("settings.json")
        watchChanges: true

        onFileChanged: reload()

        // Debounced rather than written on the spot.
        onAdapterUpdated: writeTimer.restart()

        // Only to put the file there the first time.
        onLoadFailed: {
            writeAdapter();
            root.loaded = true;
        }

        onLoaded: root.loaded = true

        JsonAdapter {
            id: adapter

            property string barColor: "#000000"
            property real barOpacity: 0.85
            property int barRadius: 0
            property int barHeight: 25
            property bool outerCorners: true
            property int outerCornerRadius: 12
            property bool barBlur: false
            property int panelRadius: 0
            property string surfaceColor: "#000000"
            property real panelOpacity: 0.85
            property bool panelBlur: false

            property real hoverOpacity: 0.26
            property int hoverRadius: 0
            property string accentColor: "#e01b24"

            property int iconSize: 12
            property int iconPadding: 3
            property int moduleSpacing: 0
            property int workspaceSpacing: 2

            property bool showNetwork: false
            property bool showBluetooth: false
            property bool showBattery: false
            property bool showRecording: false

            property var displayLayout: ({})

            property int gammaBrightness: 100

            property string notificationStyle: "integrated"
            property int notificationWidth: 380
            property int notificationHeight: 64
            property int notificationSeconds: 10

            property bool overviewPreviews: true

            property string wallpaperTransition: "fade"
            property real wallpaperTransitionSeconds: 1.2
            property string wallpaperResize: "crop"
            property string wallpaperFolder: "~/Pictures/wallpapers"

            property bool keepAwake: true
            property int idleLockMinutes: 5
            property int idleScreenOffMinutes: 10
            property int idleSuspendMinutes: 15
            property int vrr: 2
            property int directScanout: 0

            property bool clockShowSeconds: true
            property bool clockUse12Hour: false
            property bool clockShowProgress: false
            property bool calendarYearView: true
        }
    }

    Timer {
        id: writeTimer

        interval: 400
        onTriggered: fileView.writeAdapter()
    }
}
