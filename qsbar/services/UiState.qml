pragma Singleton

import Quickshell

Singleton {
    property bool controlCenterOpen: false

    // The settings window, in the middle of whichever output had focus when it was asked for.
    property bool settingsOpen: false

    // The workspace overview, which covers the whole output while it is up.
    property bool overviewOpen: false

    // Whether anything on screen is waiting to be typed into.
    property bool keyboardCapture: false
}
