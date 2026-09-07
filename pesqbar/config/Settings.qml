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

    // The four bar modules that are off until they are asked for. Each one
    // costs a polled process while it is on, so nothing here starts on its own.
    property alias showNetwork: adapter.showNetwork
    property alias showBluetooth: adapter.showBluetooth
    property alias showBattery: adapter.showBattery
    property alias showRecording: adapter.showRecording

    // The monitor arrangement the display manager saved, keyed by connector
    // name. Left out of restoreDefaults on purpose: it is a description of the
    // hardware on the desk rather than a look, and the display manager has its
    // own Reset for it.
    property alias displayLayout: adapter.displayLayout

    // Where the brightness slider was left, on a machine with no backlight for
    // it to read back from: hyprsunset applies a gamma but will not say which
    // one it is applying, so the shell has to remember. Left out of
    // restoreDefaults for the same reason as the layout above, and doubly so
    // here, since resetting the look should not black out the screen.
    property alias gammaBrightness: adapter.gammaBrightness

    // Where a toast is drawn. "integrated" hangs it off the bar as part of the
    // same surface, which is the default; "floating" is the detached card in the
    // top right corner. Only the presentation changes: the same notification,
    // the same timeout and the same control centre list either way.
    property alias notificationStyle: adapter.notificationStyle

    // How wide a toast is drawn, and how long one that did not ask for its own
    // timeout stays. An app is still allowed to name a shorter or longer life
    // for its own notification; this is only what happens when it does not.
    property alias notificationWidth: adapter.notificationWidth

    // A floor rather than a fixed height: a toast never comes out shorter than
    // this, and still grows for a body that needs the room. Setting a hard
    // height would clip the notifications that have the most to say.
    property alias notificationHeight: adapter.notificationHeight
    property alias notificationSeconds: adapter.notificationSeconds

    // Captures of the real surfaces in the overview. Off falls back to the
    // application icon, which costs nothing and always draws, on a compositor or
    // a window that will not hand a frame over.
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

        // Not written on the spot. A slider hands over a new value on every
        // mouse move, and writing there meant serialising the whole file and
        // going to disk sixty times a second for the length of a drag, with the
        // change watcher reading each one back. The write lands once the value
        // stops moving instead.
        onAdapterUpdated: writeTimer.restart()

        // Only to put the file there the first time. This used to be a blind
        // timer 1.5s after startup, which is a race the defaults can win: the
        // load is asynchronous, and a slow read meant writing defaults over
        // settings that had not arrived yet.
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
