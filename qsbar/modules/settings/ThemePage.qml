pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    spacing: 18

    Component.onCompleted: SystemTheme.refresh()

    PanelMessage {
        width: parent.width
        visible: !SystemTheme.loaded && !SettingsContext.searching
        warning: true
        text: SystemTheme.path + " could not be read. Changes apply to this session but are not kept for the next one."
    }

    Group {
        title: "Applications"

        PickerRow {
            label: "GTK theme"
            options: SystemTheme.gtkThemes
            current: SystemTheme.gtkTheme
            onPicked: value => SystemTheme.set("gtk_theme", value)
        }

        PickerRow {
            label: "Icon theme"
            options: SystemTheme.iconThemes
            current: SystemTheme.iconTheme
            onPicked: value => SystemTheme.set("icon_theme", value)
        }

        ChoiceRow {
            label: "Style"
            options: [
                {
                    value: "prefer-dark",
                    label: "Dark"
                },
                {
                    value: "prefer-light",
                    label: "Light"
                }
            ]
            current: SystemTheme.colorScheme
            onPicked: value => SystemTheme.set("color_scheme", value)
        }

        ChoiceRow {
            label: "Title bar buttons"
            options: [
                {
                    value: "close",
                    label: "Close"
                },
                {
                    value: "all",
                    label: "All"
                },
                {
                    value: "none",
                    label: "None"
                }
            ]
            current: SystemTheme.titleButtons
            onPicked: value => SystemTheme.set("title_buttons", value)
        }

        // libadwaita takes nine named accents rather than a colour.
        ToggleRow {
            label: "Accent from the bar"
            checked: SystemTheme.accentFromBar
            onToggled: SystemTheme.set("accent_from_bar", SystemTheme.accentFromBar ? 0 : 1)
        }

        ToggleRow {
            label: "Theme Flatpak apps too"
            checked: SystemTheme.flatpakTheme
            onToggled: SystemTheme.set("flatpak_theme", SystemTheme.flatpakTheme ? 0 : 1)
        }
    }

    Group {
        title: "Fonts"

        PickerRow {
            label: "Interface font"
            options: SystemTheme.fontFamilies
            current: SystemTheme.familyOf(SystemTheme.fontName)
            onPicked: value => SystemTheme.set("font_name", value + " " + SystemTheme.sizeOf(SystemTheme.fontName, 11))
        }

        StepperRow {
            label: "Interface font size"
            value: SystemTheme.sizeOf(SystemTheme.fontName, 11)
            minimum: 6
            maximum: 32
            onAdjusted: newValue => SystemTheme.set("font_name", SystemTheme.familyOf(SystemTheme.fontName) + " " + newValue)
        }

        PickerRow {
            label: "Monospace font"
            options: SystemTheme.monoFamilies
            current: SystemTheme.familyOf(SystemTheme.monospaceFontName)
            onPicked: value => SystemTheme.set("monospace_font_name", value + " " + SystemTheme.sizeOf(SystemTheme.monospaceFontName, 10))
        }

        StepperRow {
            label: "Monospace font size"
            value: SystemTheme.sizeOf(SystemTheme.monospaceFontName, 10)
            minimum: 6
            maximum: 32
            onAdjusted: newValue => SystemTheme.set("monospace_font_name", SystemTheme.familyOf(SystemTheme.monospaceFontName) + " " + newValue)
        }

        ChoiceRow {
            label: "Antialiasing"
            options: [
                {
                    value: "none",
                    label: "None"
                },
                {
                    value: "grayscale",
                    label: "Grayscale"
                },
                {
                    value: "rgba",
                    label: "Subpixel"
                }
            ]
            current: SystemTheme.fontAntialiasing
            onPicked: value => SystemTheme.set("font_antialiasing", value)
        }

        ChoiceRow {
            label: "Hinting"
            options: [
                {
                    value: "none",
                    label: "None"
                },
                {
                    value: "slight",
                    label: "Slight"
                },
                {
                    value: "medium",
                    label: "Medium"
                },
                {
                    value: "full",
                    label: "Full"
                }
            ]
            current: SystemTheme.fontHinting
            onPicked: value => SystemTheme.set("font_hinting", value)
        }

        StepperRow {
            label: "Text scaling factor"
            value: SystemTheme.textScale
            minimum: 0.5
            maximum: 3
            step: 0.01
            decimals: 2
            onAdjusted: newValue => SystemTheme.set("text_scaling_factor", newValue)
        }
    }

    Group {
        title: "Cursor"

        PickerRow {
            label: "Cursor theme"
            options: SystemTheme.cursorThemes
            current: SystemTheme.cursorTheme
            onPicked: value => SystemTheme.set("cursor_theme", value)
        }

        ChoiceRow {
            label: "Size"
            options: SystemTheme.cursorSizes.map(size => ({
                        value: size,
                        label: String(size)
                    }))
            current: SystemTheme.cursorSize
            onPicked: value => SystemTheme.set("cursor_size", value)
        }

        PanelMessage {
            width: parent.width
            visible: SystemTheme.cursorError !== "" && !SettingsContext.searching
            warning: true
            text: "Hyprland did not take the cursor: " + SystemTheme.cursorError
        }
    }
}
