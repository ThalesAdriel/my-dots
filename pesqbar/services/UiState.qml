pragma Singleton

import Quickshell

Singleton {
    property bool controlCenterOpen: false
    property bool settingsOpen: false

    // The display manager, opened from a button at the bottom of settings and
    // stacked over it, so going back lands where it was opened from.
    property bool displaysOpen: false

    // Whether anything on screen is waiting to be typed into. The bar's layer
    // surface only accepts keyboard focus while this is set, so clicking the bar
    // does not take focus off the window in front of it the rest of the time.
    property bool keyboardCapture: false
}
