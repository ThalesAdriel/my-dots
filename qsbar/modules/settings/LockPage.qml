pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    spacing: 18

    // The desktop's wallpaper too, which the button under the grid offers.
    Component.onCompleted: {
        Wallpaper.scan();
        Wallpaper.refresh();
    }

    PanelMessage {
        width: parent.width
        visible: LockConfig.broken && !SettingsContext.searching
        warning: true
        text: "quicklock.json is there but could not be read. Nothing on this page is saved until it is fixed by hand."
    }

    Group {
        title: "Wallpaper"

        WallpaperGrid {
            selected: [LockConfig.expand(LockConfig.wallpaper)]
            onPicked: path => LockConfig.wallpaper = path
        }

        // What the first output is showing.
        ButtonRow {
            readonly property string desktop: {
                const first = Wallpaper.outputs.length > 0 ? Wallpaper.current[Wallpaper.outputs[0]] : undefined;
                return first !== undefined ? first : "";
            }

            label: "Use the desktop wallpaper"
            enabledAction: desktop !== "" && desktop !== LockConfig.expand(LockConfig.wallpaper)
            onTriggered: LockConfig.wallpaper = desktop
        }

        FieldRow {
            label: "Path"
            value: LockConfig.wallpaper
            placeholder: "~/Pictures/wallpapers/w.jpg"
            browse: "file"
            nameFilters: SettingsContext.imageFilters
            onCommitted: text => LockConfig.wallpaper = text
        }
    }

    Group {
        title: "Background effects"

        SliderRow {
            label: "Dim"
            value: LockConfig.dim
            minimum: 0
            maximum: 1
            decimals: 2
            onAdjusted: newValue => LockConfig.dim = Math.round(newValue * 100) / 100
        }

        SliderRow {
            label: "Blur"
            value: LockConfig.blur
            minimum: 0
            maximum: 128
            suffix: "px"
            onAdjusted: newValue => LockConfig.blur = Math.round(newValue)
        }

        SliderRow {
            label: "Contrast"
            value: LockConfig.contrast
            minimum: -1
            maximum: 1
            decimals: 2
            onAdjusted: newValue => LockConfig.contrast = Math.round(newValue * 100) / 100
        }

        SliderRow {
            label: "Vibrancy"
            value: LockConfig.vibrancy
            minimum: -1
            maximum: 1
            decimals: 2
            onAdjusted: newValue => LockConfig.vibrancy = Math.round(newValue * 100) / 100
        }
    }

    // quicklock reads a negative radius as fully round.
    Group {
        title: "Password field"

        SliderRow {
            label: "Corner radius"
            value: LockConfig.rounding < 0 ? 26 : LockConfig.rounding
            minimum: 0
            maximum: 26
            valueText: LockConfig.rounding < 0 ? "round" : LockConfig.rounding + "px"
            onAdjusted: newValue => LockConfig.rounding = Math.round(newValue) >= 26 ? -1 : Math.round(newValue)
        }

        SliderRow {
            label: "Dot corner radius"
            value: LockConfig.dotRounding < 0 ? 6 : LockConfig.dotRounding
            minimum: 0
            maximum: 6
            valueText: LockConfig.dotRounding < 0 ? "round" : LockConfig.dotRounding + "px"
            onAdjusted: newValue => LockConfig.dotRounding = Math.round(newValue) >= 6 ? -1 : Math.round(newValue)
        }
    }

    Group {
        id: avatarGroup

        readonly property int roundAt: Math.round(LockConfig.avatarSize / 2) + 1

        title: "Avatar"

        FieldRow {
            label: "Picture"
            value: LockConfig.avatar
            placeholder: "~/.face"
            browse: "file"
            nameFilters: SettingsContext.imageFilters
            onCommitted: text => LockConfig.avatar = text
        }

        SliderRow {
            label: "Size"
            value: LockConfig.avatarSize
            minimum: 48
            maximum: 240
            suffix: "px"
            onAdjusted: newValue => LockConfig.avatarSize = Math.round(newValue)
        }

        SliderRow {
            label: "Height above centre"
            value: LockConfig.avatarOffset
            minimum: 0
            maximum: 400
            suffix: "px"
            onAdjusted: newValue => LockConfig.avatarOffset = Math.round(newValue)
        }

        SliderRow {
            label: "Corner radius"
            value: LockConfig.avatarRounding < 0 ? avatarGroup.roundAt : Math.min(LockConfig.avatarRounding, avatarGroup.roundAt)
            minimum: 0
            maximum: avatarGroup.roundAt
            valueText: LockConfig.avatarRounding < 0 ? "round" : LockConfig.avatarRounding + "px"
            onAdjusted: newValue => LockConfig.avatarRounding = Math.round(newValue) >= avatarGroup.roundAt ? -1 : Math.round(newValue)
        }
    }

    Group {
        title: "Clock"

        FieldRow {
            label: "Time format"
            value: LockConfig.timeFormat
            placeholder: "HH:mm"
            onCommitted: text => LockConfig.timeFormat = text
        }

        FieldRow {
            label: "Date format"
            value: LockConfig.dateFormat
            placeholder: "dddd, MMMM dd"
            onCommitted: text => LockConfig.dateFormat = text
        }

        // Read once when the page is built: this is a check that a format means what you think, not a clock.
        PanelMessage {
            width: parent.width
            visible: !SettingsContext.searching
            text: {
                const now = new Date();
                return "Qt date format. Right now that reads " + Qt.formatDateTime(now, LockConfig.timeFormat) + "  ·  " + Qt.formatDateTime(now, LockConfig.dateFormat);
            }
        }
    }

    Group {
        title: "Behaviour"

        ToggleRow {
            label: "Keep the screen awake while locked"
            checked: LockConfig.caffeine
            onToggled: LockConfig.caffeine = !LockConfig.caffeine
        }

        FieldRow {
            label: "Caffeine glyph"
            value: LockConfig.caffeineIcon
            onCommitted: text => LockConfig.caffeineIcon = text
        }

        FieldRow {
            label: "Glyph font"
            value: LockConfig.iconFont
            placeholder: "Font Awesome 7 Free"
            onCommitted: text => LockConfig.iconFont = text
        }

        FieldRow {
            label: "PAM service"
            value: LockConfig.pam
            placeholder: "login"
            onCommitted: text => LockConfig.setPam(text.trim())
        }

        PanelMessage {
            width: parent.width
            visible: LockConfig.pamError !== "" && !SettingsContext.searching
            warning: true
            text: LockConfig.pamError
        }
    }

    // Only this page's: the one in the sidebar is the shell's own look and leaves quicklock.json alone.
    ButtonRow {
        label: "Restore lock screen defaults"
        onTriggered: LockConfig.restoreDefaults()
    }
}
