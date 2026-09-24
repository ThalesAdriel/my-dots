pragma Singleton

import Quickshell

Singleton {
    property bool controlCenterOpen: false

    // The settings window, in the middle of whichever output had focus when it was asked for; opened from the gear in the control center or over IPC from a Hyprland keybind.
    property bool settingsOpen: false

    // The workspace overview, which covers the whole output while it is up; opened from the bar or over IPC from a Hyprland keybind.
    property bool overviewOpen: false

    // Whether anything on screen is waiting to be typed into: the bar's layer surface only accepts keyboard focus while this is set, so clicking the bar does not steal focus the rest of the time.
    property bool keyboardCapture: false
}
