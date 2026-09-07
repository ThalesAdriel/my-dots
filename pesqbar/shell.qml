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

    // Covers the whole output when it is up, so it hangs off the root rather
    // than off the bar. Opened over IPC from a Hyprland keybind.
    Overview {
    }

    // Only ever on screen for the three seconds after Identify is pressed, but
    // one per output, so it has to hang off the root next to the bar rather
    // than inside it.
    Variants {
        model: Quickshell.screens

        IdentifyOverlay {
        }
    }
}
