pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: barPage

    property string tab: "bar"

    spacing: 18

    SubTabs {
        tabs: [
            {
                value: "bar",
                label: "Bar"
            },
            {
                value: "clock",
                label: "Clock"
            },
            {
                value: "notifications",
                label: "Notifications"
            }
        ]
        current: barPage.tab
        onPicked: value => barPage.tab = value
    }

    Column {
        id: barTab

        readonly property string searchTitle: "Bar"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(barTab.children)

        width: parent.width
        spacing: 18
        visible: SettingsContext.searching ? barTab.hit : barPage.tab === "bar"

        Group {
            title: "Bar"

            SwatchRow {
                label: "Colour"
                options: SettingsContext.surfaceColors
                current: Settings.barColor
                onPicked: value => Settings.barColor = value
            }

            SliderRow {
                label: "Opacity"
                value: Settings.barOpacity
                minimum: 0
                maximum: 1
                decimals: 2
                onAdjusted: newValue => Settings.barOpacity = newValue
            }

            SliderRow {
                label: "Height"
                value: Settings.barHeight
                minimum: 24
                maximum: 48
                suffix: "px"
                onAdjusted: newValue => Settings.barHeight = Math.round(newValue)
            }

            SliderRow {
                label: "Corner radius"
                value: Settings.barRadius
                minimum: 0
                maximum: 20
                suffix: "px"
                onAdjusted: newValue => Settings.barRadius = Math.round(newValue)
            }

            ToggleRow {
                label: "Background blur"
                checked: Settings.barBlur
                onToggled: Settings.barBlur = !Settings.barBlur
            }
        }

        Group {
            title: "Outer corners"

            ToggleRow {
                label: "Round into the screen edges"
                checked: Settings.outerCorners
                onToggled: Settings.outerCorners = !Settings.outerCorners
            }

            SliderRow {
                applies: Settings.outerCorners
                label: "Corner size"
                value: Settings.outerCornerRadius
                minimum: 4
                maximum: 32
                suffix: "px"
                onAdjusted: newValue => Settings.outerCornerRadius = Math.round(newValue)
            }
        }

        Group {
            title: "Icons and spacing"

            SliderRow {
                label: "Icon size"
                value: Settings.iconSize
                minimum: 10
                maximum: 24
                suffix: "px"
                onAdjusted: newValue => Settings.iconSize = Math.round(newValue)
            }

            SliderRow {
                label: "Icon padding"
                value: Settings.iconPadding
                minimum: 0
                maximum: 12
                suffix: "px"
                onAdjusted: newValue => Settings.iconPadding = Math.round(newValue)
            }

            SliderRow {
                label: "Module spacing"
                value: Settings.moduleSpacing
                minimum: 0
                maximum: 16
                suffix: "px"
                onAdjusted: newValue => Settings.moduleSpacing = Math.round(newValue)
            }

            SliderRow {
                label: "Workspace spacing"
                value: Settings.workspaceSpacing
                minimum: 2
                maximum: 28
                suffix: "px"
                onAdjusted: newValue => Settings.workspaceSpacing = Math.round(newValue)
            }
        }

        // Everything here is off out of the box.
        Group {
            title: "Bar modules"

            ToggleRow {
                label: "Wi-Fi and Ethernet"
                checked: Settings.showNetwork
                onToggled: Settings.showNetwork = !Settings.showNetwork
            }

            ToggleRow {
                label: "VPN (always shown when active)"
                checked: Settings.showVpn
                onToggled: Settings.showVpn = !Settings.showVpn
            }

            ToggleRow {
                label: "Bluetooth"
                checked: Settings.showBluetooth
                onToggled: Settings.showBluetooth = !Settings.showBluetooth
            }

            ToggleRow {
                label: "Battery"
                checked: Settings.showBattery
                onToggled: Settings.showBattery = !Settings.showBattery
            }

            ToggleRow {
                label: "Battery percentage"
                applies: Settings.showBattery
                checked: Settings.showBatteryPercent
                onToggled: Settings.showBatteryPercent = !Settings.showBatteryPercent
            }

            ToggleRow {
                label: "Screen recording"
                checked: Settings.showRecording
                onToggled: Settings.showRecording = !Settings.showRecording
            }

            // The cup in the bar: while it is on, hypridle's timeouts under Displays never run.
            ToggleRow {
                label: "Keep awake"
                checked: Settings.keepAwake
                onToggled: Settings.keepAwake = !Settings.keepAwake
            }

            ToggleRow {
                label: "Night light in Control Center"
                checked: Settings.showNightLight
                onToggled: Settings.showNightLight = !Settings.showNightLight
            }

            ToggleRow {
                label: "Power plan in Control Center"
                checked: Settings.showPowerProfiles
                onToggled: Settings.showPowerProfiles = !Settings.showPowerProfiles
            }
        }
    }

    Column {
        id: clockTab

        readonly property string searchTitle: "Clock calendar overview settings"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(clockTab.children)

        width: parent.width
        spacing: 18
        visible: SettingsContext.searching ? clockTab.hit : barPage.tab === "clock"

        Group {
            title: "Clock and calendar"

            ToggleRow {
                label: "Show seconds"
                checked: Settings.clockShowSeconds
                onToggled: Settings.clockShowSeconds = !Settings.clockShowSeconds
            }

            ToggleRow {
                label: "12 hour clock"
                checked: Settings.clockUse12Hour
                onToggled: Settings.clockUse12Hour = !Settings.clockUse12Hour
            }

            ToggleRow {
                label: "Minute progress line"
                checked: Settings.clockShowProgress
                onToggled: Settings.clockShowProgress = !Settings.clockShowProgress
            }

            ToggleRow {
                label: "Calendar opens on year view"
                checked: Settings.calendarYearView
                onToggled: Settings.calendarYearView = !Settings.calendarYearView
            }
        }

        Group {
            title: "Overview and settings"

            ToggleRow {
                label: "Window previews in overview"
                checked: Settings.overviewPreviews
                onToggled: Settings.overviewPreviews = !Settings.overviewPreviews
            }

            SliderRow {
                label: "Settings scroll speed"
                value: Settings.settingsScrollSpeed
                minimum: 0.4
                maximum: 2.5
                decimals: 1
                suffix: "x"
                onAdjusted: newValue => Settings.settingsScrollSpeed = Math.round(newValue * 10) / 10
            }
        }
    }

    Column {
        id: notificationsTab

        readonly property string searchTitle: "Notifications toast popups dnd"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(notificationsTab.children)

        width: parent.width
        spacing: 18
        visible: SettingsContext.searching ? notificationsTab.hit : barPage.tab === "notifications"

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
}
