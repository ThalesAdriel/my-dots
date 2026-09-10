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
