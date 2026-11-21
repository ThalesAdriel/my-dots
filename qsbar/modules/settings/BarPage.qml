pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    spacing: 18

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
            label: "Corner size"
            value: Settings.outerCornerRadius
            minimum: 4
            maximum: 32
            suffix: "px"
            onAdjusted: newValue => Settings.outerCornerRadius = Math.round(newValue)
        }
    }

    // Everything here is off out of the box.
    Group {
        title: "Bar components"

        ToggleRow {
            label: "Wi-Fi and Ethernet"
            checked: Settings.showNetwork
            onToggled: Settings.showNetwork = !Settings.showNetwork
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
    }
}
