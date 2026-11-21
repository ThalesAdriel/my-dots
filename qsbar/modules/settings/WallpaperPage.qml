pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: wallpaperColumn

    // Which output a click sets, or all of them.
    property string target: ""

    spacing: 18

    Component.onCompleted: {
        Wallpaper.scan();
        Wallpaper.refresh();
    }

    PanelMessage {
        width: parent.width
        visible: !Wallpaper.available && !SettingsContext.searching
        warning: true
        text: "awww is not answering, so the desktop wallpaper cannot be changed. Is awww-daemon running?"
    }

    Group {
        title: "Desktop"

        // Only asked with more than one output to tell apart.
        ChoiceRow {
            applies: Wallpaper.outputs.length > 1
            label: "Screen"
            options: [
                {
                    value: "",
                    label: "All"
                }
            ].concat(Wallpaper.outputs.map(name => ({
                        value: name,
                        label: name
                    })))
            current: wallpaperColumn.target
            onPicked: value => wallpaperColumn.target = value
        }

        WallpaperGrid {
            selected: {
                if (wallpaperColumn.target === "")
                    return Object.values(Wallpaper.current);
                const shown = Wallpaper.current[wallpaperColumn.target];
                return shown !== undefined ? [shown] : [];
            }
            onPicked: path => Wallpaper.apply(path, wallpaperColumn.target)
        }

        // Only shows once awww draws again.
        ChoiceRow {
            label: "Scaling"
            options: [
                {
                    value: "crop",
                    label: "Fill"
                },
                {
                    value: "fit",
                    label: "Fit"
                },
                {
                    value: "no",
                    label: "Center"
                }
            ]
            current: Settings.wallpaperResize
            onPicked: value => {
                Settings.wallpaperResize = value;
                Wallpaper.reapply();
            }
        }

        PanelMessage {
            width: parent.width
            visible: Wallpaper.lastError !== "" && !SettingsContext.searching
            warning: true
            text: Wallpaper.lastError
        }

        // The lock screen grid lists the same folder.
        FieldRow {
            label: "Folder"
            value: Settings.wallpaperFolder
            placeholder: "~/Pictures/wallpapers"
            browse: "folder"
            onCommitted: text => Settings.wallpaperFolder = text.trim()
        }
    }

    Group {
        title: "Transition"

        ChoiceRow {
            label: "Style"
            options: Wallpaper.transitions
            current: Settings.wallpaperTransition
            onPicked: value => Settings.wallpaperTransition = value
        }

        SliderRow {
            applies: Settings.wallpaperTransition !== "none"
            label: "Duration"
            value: Settings.wallpaperTransitionSeconds
            minimum: 0.2
            maximum: 3
            decimals: 1
            suffix: "s"
            onAdjusted: newValue => Settings.wallpaperTransitionSeconds = Math.round(newValue * 10) / 10
        }
    }
}
