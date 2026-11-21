pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    spacing: 18

    Group {
        title: "Accent and hover"

        SwatchRow {
            label: "Accent colour"
            options: SettingsContext.accentColors
            current: Settings.accentColor
            onPicked: value => Settings.accentColor = value
        }

        SliderRow {
            label: "Hover opacity"
            value: Settings.hoverOpacity
            minimum: 0
            maximum: 0.6
            decimals: 2
            onAdjusted: newValue => Settings.hoverOpacity = newValue
        }

        SliderRow {
            label: "Hover corner radius"
            value: Settings.hoverRadius
            minimum: 0
            maximum: 20
            suffix: "px"
            onAdjusted: newValue => Settings.hoverRadius = Math.round(newValue)
        }
    }

    Group {
        title: "Panels"

        SwatchRow {
            label: "Surface colour"
            options: SettingsContext.surfaceColors
            current: Settings.surfaceColor
            onPicked: value => Settings.surfaceColor = value
        }

        SliderRow {
            label: "Opacity"
            value: Settings.panelOpacity
            minimum: 0.3
            maximum: 1
            decimals: 2
            onAdjusted: newValue => Settings.panelOpacity = newValue
        }

        SliderRow {
            label: "Corner radius"
            value: Settings.panelRadius
            minimum: 0
            maximum: 24
            suffix: "px"
            onAdjusted: newValue => Settings.panelRadius = Math.round(newValue)
        }

        ToggleRow {
            label: "Background blur"
            checked: Settings.panelBlur
            onToggled: Settings.panelBlur = !Settings.panelBlur
        }

        ButtonRow {
            label: "Match bar colour and opacity"
            enabledAction: Settings.surfaceColor !== Settings.barColor || Settings.panelOpacity !== Settings.barOpacity
            onTriggered: {
                Settings.surfaceColor = Settings.barColor;
                Settings.panelOpacity = Settings.barOpacity;
            }
        }
    }

    Group {
        title: "Icons"

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
}
