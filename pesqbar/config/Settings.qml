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
    property alias showTopBorder: adapter.showTopBorder
    property alias showPanelBorders: adapter.showPanelBorders
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

    // The saved monitor arrangement, keyed by connector. Out of restoreDefaults on purpose: it describes the hardware rather than a look, and has its own Reset.
    property alias displayLayout: adapter.displayLayout

    // Where the brightness slider was left on a machine with no backlight to read back from, since hyprsunset never reports the gamma it applies. Out of restoreDefaults so a reset cannot black out the screen.
    property alias gammaBrightness: adapter.gammaBrightness

    // Where a toast is drawn: "integrated" hangs it off the bar, "floating" is the detached card. Only the presentation changes.
    property alias notificationStyle: adapter.notificationStyle

    // How wide a toast is drawn, and how long one that named no timeout of its own stays; an app can still name its own.
    property alias notificationWidth: adapter.notificationWidth

    // A floor rather than a fixed height: a toast never comes out shorter, and still grows for a body that needs the room.
    property alias notificationHeight: adapter.notificationHeight
    property alias notificationSeconds: adapter.notificationSeconds

    // Real surface captures in the overview; off falls back to the application icon, which costs nothing and always draws.
    property alias overviewPreviews: adapter.overviewPreviews

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
        adapter.showTopBorder = false;
        adapter.showPanelBorders = false;
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

        // Debounced rather than written on the spot: a drag hands over a value per mouse move, and writing there serialised the whole file sixty times a second.
        onAdapterUpdated: writeTimer.restart()

        // Only to put the file there the first time. A blind startup timer raced the asynchronous load and wrote defaults over settings that had not arrived yet.
        onLoadFailed: writeAdapter()

        JsonAdapter {
            id: adapter

            property string barColor: "#000000"
            property real barOpacity: 0.85
            property int barRadius: 0
            property int barHeight: 25
            property bool outerCorners: true
            property int outerCornerRadius: 12
            property bool showTopBorder: false
            property bool showPanelBorders: false
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
