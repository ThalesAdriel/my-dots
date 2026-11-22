pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    spacing: 18

    Group {
        title: "Notifications"

        // A string rather than a bool in settings.
        ChoiceRow {
            label: "Toast style"
            options: [
                {
                    value: "integrated",
                    label: "Attached"
                },
                {
                    value: "floating",
                    label: "Floating"
                }
            ]
            current: Settings.notificationStyle
            onPicked: value => Settings.notificationStyle = value
        }

        SliderRow {
            label: "Width"
            value: Settings.notificationWidth
            minimum: 280
            maximum: 560
            suffix: "px"
            onAdjusted: newValue => Settings.notificationWidth = Math.round(newValue)
        }

        SliderRow {
            label: "Minimum height"
            value: Settings.notificationHeight
            minimum: 44
            maximum: 140
            suffix: "px"
            onAdjusted: newValue => Settings.notificationHeight = Math.round(newValue)
        }

        // What a notification that named no timeout of its own gets.
        SliderRow {
            label: "Time on screen"
            value: Settings.notificationSeconds
            minimum: 2
            maximum: 30
            suffix: "s"
            onAdjusted: newValue => Settings.notificationSeconds = Math.round(newValue)
        }

        ToggleRow {
            label: "Pause popups in fullscreen"
            checked: Settings.dndOnFullscreen
            onToggled: Settings.dndOnFullscreen = !Settings.dndOnFullscreen
        }
    }
}
