pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Keeps the machine awake while the greeter is up.
Singleton {
    id: root

    property bool active: false
    property bool broken: false

    function toggle() {
        root.broken = false;
        root.active = !root.active;
    }

    Process {
        id: inhibitor

        running: root.active
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=quickgreet", "--why=Caffeine", "--mode=block", "cat"]

        onExited: {
            if (root.active) {
                root.active = false;
                root.broken = true;
            }
        }
    }
}
