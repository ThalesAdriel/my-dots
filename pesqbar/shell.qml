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

    // Only ever on screen for the three seconds after Identify is pressed, but
    // one per output, so it has to hang off the root next to the bar rather
    // than inside it.
    Variants {
        model: Quickshell.screens

        IdentifyOverlay {
        }
    }
}
