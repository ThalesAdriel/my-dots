import QtQuick
import Quickshell
import "root:/modules"
import "root:/services"

ShellRoot {
    // Built from the start rather than when the theme page first asks for it.
    Component.onCompleted: SystemTheme.followAccent()

    Variants {
        model: Quickshell.screens

        Bar {
        }
    }

    NotificationPopups {
    }

    // One instance, not one per output.
    MediaKeys {
    }

    PolkitDialog {
    }

    // The idle timeouts and game options go out to hypridle and Hyprland as files.
    HyprSync {
    }

    // Covers the whole output, so it hangs off the root rather than the bar.
    Overview {
    }

    // One window for every output, opened on whichever had focus.
    SettingsWindow {
    }

    // Three seconds on screen after Identify is pressed, but one per output.
    Variants {
        model: Quickshell.screens

        IdentifyOverlay {
        }
    }
}
