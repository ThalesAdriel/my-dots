pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool active: false
    property bool broken: false

    function toggle() {
        root.broken = false;
        root.active = !root.active;
    }

    onActiveChanged: {
        inhibitor.running = root.active;
    }

    Component.onCompleted: {
        root.active = Config.caffeineDefault;
        inhibitor.running = root.active;
    }

    Process {
        id: inhibitor

        running: false
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=quicklock", "--why=Caffeine", "--mode=block", "cat"]

        onExited: {
            if (root.active) {
                root.active = false;
                root.broken = true;
            }
        }
    }
}
