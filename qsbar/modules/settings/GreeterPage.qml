pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    spacing: 18

    Component.onCompleted: {
        Wallpaper.scan();
        Wallpaper.refresh();
    }

    PanelMessage {
        width: parent.width
        visible: GreetConfig.missing && !SettingsContext.searching
        warning: true
        text: "quickgreet is not installed, so nothing on this page is saved. Run ./install.sh config from the dotfiles first."
    }

    PanelMessage {
        width: parent.width
        visible: GreetConfig.broken && !SettingsContext.searching
        warning: true
        text: "quickgreet.json is there but could not be read. Nothing on this page is saved until it is fixed by hand."
    }

    PanelMessage {
        width: parent.width
        visible: GreetConfig.lastError !== "" && !SettingsContext.searching
        warning: true
        text: GreetConfig.lastError
    }

    Group {
        title: "Test"

        ButtonRow {
            label: "Test the login screen"
            onTriggered: GreetConfig.test()
        }
    }

    Group {
        title: "Background"

        ChoiceRow {
            label: "Background"
            options: [
                {
                    value: "image",
                    label: "Picture"
                },
                {
                    value: "color",
                    label: "Solid colour"
                }
            ]
            current: GreetConfig.background
            onPicked: value => GreetConfig.background = value
        }

        WallpaperGrid {
            visible: !SettingsContext.searching && GreetConfig.background === "image"
            selected: [GreetConfig.expand(GreetConfig.wallpaper)]
            onPicked: path => GreetConfig.setPicture("wallpaper", path)
        }

        // What the first output is showing.
        ButtonRow {
            readonly property string desktop: {
                const first = Wallpaper.outputs.length > 0 ? Wallpaper.current[Wallpaper.outputs[0]] : undefined;
                return first !== undefined ? first : "";
            }

            label: "Use the desktop wallpaper"
            applies: GreetConfig.background === "image"
            enabledAction: desktop !== "" && desktop !== GreetConfig.expand(GreetConfig.wallpaper)
            onTriggered: GreetConfig.setPicture("wallpaper", desktop)
        }

        FieldRow {
            label: "Path"
            applies: GreetConfig.background === "image"
            value: GreetConfig.wallpaper
            placeholder: "~/Pictures/wallpapers/w.jpg"
            browse: "file"
            nameFilters: SettingsContext.imageFilters
            onCommitted: text => GreetConfig.setPicture("wallpaper", text)
        }

        SwatchRow {
            label: "Colour"
            applies: GreetConfig.background === "color"
            options: SettingsContext.surfaceColors
            current: GreetConfig.color
            onPicked: value => GreetConfig.color = value
        }

        SliderRow {
            label: "Dim"
            applies: GreetConfig.background === "image"
            value: GreetConfig.dim
            minimum: 0
            maximum: 1
            decimals: 2
            onAdjusted: newValue => GreetConfig.dim = Math.round(newValue * 100) / 100
        }

        SliderRow {
            label: "Blur"
            applies: GreetConfig.background === "image"
            value: GreetConfig.blur
            minimum: 0
            maximum: 128
            suffix: "px"
            onAdjusted: newValue => GreetConfig.blur = Math.round(newValue)
        }
    }

    Group {
        title: "Animation layer"

        PickerRow {
            label: "ASCII animation"
            options: GreetConfig.animations
            current: GreetConfig.animation
            labelOf: value => GreetConfig.label(value)
            onPicked: value => GreetConfig.animation = value
        }

        SliderRow {
            label: "Opacity"
            applies: GreetConfig.animation !== "none"
            value: GreetConfig.animationOpacity
            minimum: 0.05
            maximum: 1
            decimals: 2
            onAdjusted: newValue => GreetConfig.animationOpacity = Math.round(newValue * 100) / 100
        }

        // A slower animation is also a cheaper one: speed sets how often a frame is drawn.
        SliderRow {
            label: "Speed"
            applies: GreetConfig.animation !== "none"
            value: GreetConfig.animationSpeed
            minimum: 25
            maximum: 200
            suffix: "%"
            onAdjusted: newValue => GreetConfig.animationSpeed = Math.round(newValue / 5) * 5
        }
    }

    Group {
        title: "Card & layout"

        ChoiceRow {
            label: "Position"
            options: [
                {
                    value: "left",
                    label: "Left"
                },
                {
                    value: "center",
                    label: "Center"
                },
                {
                    value: "right",
                    label: "Right"
                }
            ]
            current: GreetConfig.cardPosition
            onPicked: value => GreetConfig.cardPosition = value
        }

        SliderRow {
            label: "Card opacity"
            value: GreetConfig.cardOpacity
            minimum: 0.2
            maximum: 1
            decimals: 2
            onAdjusted: newValue => GreetConfig.cardOpacity = Math.round(newValue * 100) / 100
        }

        // The greeter already follows the screen's height; this is on top of that.
        SliderRow {
            label: "Scale"
            value: GreetConfig.uiScale * 100
            minimum: 50
            maximum: 150
            suffix: "%"
            onAdjusted: newValue => GreetConfig.uiScale = Math.round(newValue / 5) / 20
        }

        PickerRow {
            label: "Border"
            options: GreetConfig.borders
            current: GreetConfig.border
            labelOf: value => GreetConfig.label(value)
            onPicked: value => GreetConfig.border = value
        }

        SliderRow {
            label: "Corner radius"
            value: GreetConfig.rounding
            minimum: 0
            maximum: 30
            suffix: "px"
            onAdjusted: newValue => GreetConfig.rounding = Math.round(newValue)
        }

        PickerRow {
            label: "Colour theme"
            options: GreetConfig.themes
            current: GreetConfig.theme
            labelOf: value => GreetConfig.label(value)
            onPicked: value => GreetConfig.theme = value
        }
    }

    Group {
        title: "Avatar"

        ToggleRow {
            label: "Show avatar"
            checked: GreetConfig.showAvatar
            onToggled: GreetConfig.showAvatar = !GreetConfig.showAvatar
        }

        FieldRow {
            label: "Picture"
            applies: GreetConfig.showAvatar
            value: GreetConfig.avatar
            placeholder: "the account's own, or a silhouette"
            browse: "file"
            nameFilters: SettingsContext.imageFilters
            onCommitted: text => GreetConfig.setPicture("avatar", text)
        }
    }

    Group {
        title: "Clock"

        ToggleRow {
            label: "Show clock and date"
            checked: GreetConfig.showClock
            onToggled: GreetConfig.showClock = !GreetConfig.showClock
        }

        ToggleRow {
            label: "Use 12-hour clock"
            applies: GreetConfig.showClock
            checked: GreetConfig.clockUse12Hour
            onToggled: GreetConfig.clockUse12Hour = !GreetConfig.clockUse12Hour
        }

        ToggleRow {
            label: "Show seconds"
            applies: GreetConfig.showClock
            checked: GreetConfig.clockShowSeconds
            onToggled: GreetConfig.clockShowSeconds = !GreetConfig.clockShowSeconds
        }

        SliderRow {
            label: "Clock size"
            applies: GreetConfig.showClock
            value: GreetConfig.clockSize
            minimum: 36
            maximum: 96
            suffix: "px"
            onAdjusted: newValue => GreetConfig.clockSize = Math.round(newValue)
        }
    }

    Group {
        title: "Display and status"

        ToggleRow {
            label: "Show battery indicator"
            checked: GreetConfig.showBattery
            onToggled: GreetConfig.showBattery = !GreetConfig.showBattery
        }

        ToggleRow {
            label: "Show power buttons"
            checked: GreetConfig.showPowerButtons
            onToggled: GreetConfig.showPowerButtons = !GreetConfig.showPowerButtons
        }

        ToggleRow {
            label: "Show session menu"
            checked: GreetConfig.showSessionMenu
            onToggled: GreetConfig.showSessionMenu = !GreetConfig.showSessionMenu
        }

        ToggleRow {
            label: "Follow pointer across monitors"
            checked: GreetConfig.followPointer
            onToggled: GreetConfig.followPointer = !GreetConfig.followPointer
        }
    }

    // Only this page's: the one in the sidebar is the shell's own look and leaves quickgreet.json alone.
    ButtonRow {
        label: "Restore login screen defaults"
        onTriggered: GreetConfig.restoreDefaults()
    }
}
