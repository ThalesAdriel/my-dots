import Quickshell
import "root:/modules"

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
        }
    }

    NotificationPopups {
    }

    // One instance, not one per output: both register IPC targets, and a polkit prompt belongs on the focused screen rather than on every one of them.
    MediaKeys {
    }

    PolkitDialog {
    }

    // Covers the whole output, so it hangs off the root rather than the bar; opened over IPC from a Hyprland keybind.
    Overview {
    }

    // Three seconds on screen after Identify is pressed, but one per output, so it sits beside the bar rather than inside it.
    Variants {
        model: Quickshell.screens

        IdentifyOverlay {
        }
    }
}
