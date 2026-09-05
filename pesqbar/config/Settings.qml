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
        onAdapterUpdated: writeAdapter()

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

            property bool clockShowSeconds: true
            property bool clockUse12Hour: false
            property bool clockShowProgress: false
            property bool calendarYearView: true
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: fileView.writeAdapter()
    }
}
