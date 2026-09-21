import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

Scope {
    id: root

    WlSessionLock {
        id: lock

        locked: true

        onLockedChanged: {
            if (!lock.locked)
                farewell.start();
        }

        WlSessionLockSurface {
            color: Config.background

            Surface {
                anchors.fill: parent
            }
        }
    }

    Connections {
        target: Auth

        function onUnlocked() {
            release.start();
        }
    }

    Timer {
        id: release
        interval: Config.animNormal
        onTriggered: lock.locked = false
    }

    Timer {
        id: farewell
        interval: 200
        onTriggered: Qt.quit()
    }
}
