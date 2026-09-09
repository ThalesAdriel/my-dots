pragma Singleton

import Quickshell

Singleton {
    property bool controlCenterOpen: false
    property bool settingsOpen: false

    // The display manager, opened from a button at the bottom of settings and stacked over it, so going back lands where it was opened from.
    property bool displaysOpen: false

    // The workspace overview, which covers the whole output while it is up; opened from the bar or over IPC from a Hyprland keybind.
    property bool overviewOpen: false

    // Whether anything on screen is waiting to be typed into: the bar's layer surface only accepts keyboard focus while this is set, so clicking the bar does not steal focus the rest of the time.
    property bool keyboardCapture: false
}
