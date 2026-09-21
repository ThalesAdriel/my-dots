pragma Singleton

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    property date now: new Date()

    readonly property string time: Qt.formatDateTime(root.now, Config.timeFormat)
    readonly property string date: Qt.formatDateTime(root.now, Config.dateFormat)

    function remaining(): int {
        const d = new Date();
        return 60000 - (d.getSeconds() * 1000 + d.getMilliseconds()) + 25;
    }

    Timer {
        id: tick
        repeat: false
        interval: root.remaining()
        running: true
        onTriggered: {
            root.now = new Date();
            interval = root.remaining();
            start();
        }
    }
}
