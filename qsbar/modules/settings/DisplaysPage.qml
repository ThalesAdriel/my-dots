pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"
import "root:/modules"

Column {
    id: displaysPage

    property string tab: "monitors"

    spacing: 18

    SubTabs {
        tabs: [
            {
                value: "monitors",
                label: "Displays"
            },
            {
                value: "idle",
                label: "Idle"
            },
            {
                value: "gaming",
                label: "Gaming"
            }
        ]
        current: displaysPage.tab
        onPicked: value => displaysPage.tab = value
    }

    Loader {
        width: parent.width
        active: !SettingsContext.searching && displaysPage.tab === "monitors"
        visible: active

        sourceComponent: DisplayManager {
            Component.onCompleted: Displays.watching = true
            Component.onDestruction: Displays.watching = false
        }
    }

    Column {
        id: idleTab

        readonly property string searchTitle: "Idle power sleep suspend lock screen"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(idleTab.children)

        width: parent.width
        spacing: 18
        visible: SettingsContext.searching ? idleTab.hit : displaysPage.tab === "idle"

        // hypridle's timeouts, which only run while keep awake, the cup in the bar, is off.
        Group {
            title: "Idle"

            SliderRow {
                label: "Lock after"
                value: Settings.idleLockMinutes
                minimum: 0
                maximum: 60
                valueText: Settings.idleLockMinutes === 0 ? "never" : Settings.idleLockMinutes + " min"
                onAdjusted: newValue => Settings.idleLockMinutes = Math.round(newValue)
            }

            SliderRow {
                label: "Turn screens off after"
                value: Settings.idleScreenOffMinutes
                minimum: 0
                maximum: 60
                valueText: Settings.idleScreenOffMinutes === 0 ? "never" : Settings.idleScreenOffMinutes + " min"
                onAdjusted: newValue => Settings.idleScreenOffMinutes = Math.round(newValue)
            }

            SliderRow {
                label: "Suspend after"
                value: Settings.idleSuspendMinutes
                minimum: 0
                maximum: 120
                valueText: Settings.idleSuspendMinutes === 0 ? "never" : Settings.idleSuspendMinutes + " min"
                onAdjusted: newValue => Settings.idleSuspendMinutes = Math.round(newValue)
            }
        }
    }

    Column {
        id: gamingTab

        readonly property string searchTitle: "Gaming games vrr variable refresh rate direct scanout"
        readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(gamingTab.children)

        width: parent.width
        spacing: 18
        visible: SettingsContext.searching ? gamingTab.hit : displaysPage.tab === "gaming"

        Group {
            title: "Gaming"

            ChoiceRow {
                label: "Variable refresh rate"
                options: [
                    {
                        value: 0,
                        label: "Off"
                    },
                    {
                        value: 2,
                        label: "Fullscreen"
                    },
                    {
                        value: 1,
                        label: "Always"
                    }
                ]
                current: Settings.vrr
                onPicked: value => Settings.vrr = value
            }

            // Games is Hyprland's 2, only for a window that says it is a game.
            ChoiceRow {
                label: "Direct scanout"
                options: [
                    {
                        value: 0,
                        label: "Off"
                    },
                    {
                        value: 2,
                        label: "Games"
                    },
                    {
                        value: 1,
                        label: "Fullscreen"
                    }
                ]
                current: Settings.directScanout
                onPicked: value => Settings.directScanout = value
            }
        }
    }
}
