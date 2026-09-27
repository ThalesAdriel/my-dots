pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Quickshell aligns SystemClock to the wall clock itself, so the minute turns over when the minute turns over. What was here before worked its own interval out of Date.now, re-armed itself on every tick, carried a 25ms fudge to land on the right side of the boundary, and ticked per minute whatever the configured format asked for.
Singleton {
    id: root

    readonly property string time: Qt.formatDateTime(clock.date, Config.timeFormat)
    readonly property string date: Qt.formatDateTime(clock.date, Config.dateFormat)

    SystemClock {
        id: clock

        precision: Config.secondsVisible ? SystemClock.Seconds : SystemClock.Minutes
    }
}
