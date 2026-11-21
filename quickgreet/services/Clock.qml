pragma Singleton

import QtQuick
import Quickshell

// Quickshell aligns SystemClock to the wall clock itself — no 1s polling.
Singleton {
    id: root

    readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")
    readonly property string date: Qt.formatDateTime(clock.date, "dddd, MMMM dd")

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
