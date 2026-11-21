pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    spacing: 18

    Group {
        title: "Clock and calendar"

        ToggleRow {
            label: "Show seconds"
            checked: Settings.clockShowSeconds
            onToggled: Settings.clockShowSeconds = !Settings.clockShowSeconds
        }

        ToggleRow {
            label: "12 hour clock"
            checked: Settings.clockUse12Hour
            onToggled: Settings.clockUse12Hour = !Settings.clockUse12Hour
        }

        ToggleRow {
            label: "Minute progress line"
            checked: Settings.clockShowProgress
            onToggled: Settings.clockShowProgress = !Settings.clockShowProgress
        }

        ToggleRow {
            label: "Calendar opens on year view"
            checked: Settings.calendarYearView
            onToggled: Settings.calendarYearView = !Settings.calendarYearView
        }
    }

    Group {
        title: "Overview"

        ToggleRow {
            label: "Window previews"
            checked: Settings.overviewPreviews
            onToggled: Settings.overviewPreviews = !Settings.overviewPreviews
        }
    }
}
