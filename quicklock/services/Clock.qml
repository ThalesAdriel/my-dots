pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Quickshell aligns SystemClock to the wall clock itself.
Singleton {
    id: root

    readonly property string time: Qt.formatDateTime(clock.date, Config.timeFormat)
    readonly property string date: Qt.formatDateTime(clock.date, Config.dateFormat)

    SystemClock {
        id: clock

        precision: Config.secondsVisible ? SystemClock.Seconds : SystemClock.Minutes
    }
}
