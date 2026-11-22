pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Quickshell aligns SystemClock to the wall clock itself — no 1s polling unless seconds are shown.
Singleton {
    id: root

    readonly property string timeFormat: Config.clockUse12Hour
        ? (Config.clockShowSeconds ? "hh:mm:ss AP" : "hh:mm AP")
        : (Config.clockShowSeconds ? "HH:mm:ss" : "HH:mm")

    readonly property string time: Qt.formatDateTime(clock.date, root.timeFormat)
    readonly property string date: Qt.formatDateTime(clock.date, "dddd, MMMM dd")

    SystemClock {
        id: clock

        precision: Config.clockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
