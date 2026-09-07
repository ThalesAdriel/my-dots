import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

BarButton {
    id: root

    leftPadding: 8
    rightPadding: 12
    highlighted: calendarPopup.shown

    onPrimaryClicked: calendarPopup.toggle()

    // Through the calendar rather than straight at the setting: an offset counts
    // months in one view and years in the other, so it has to be reset with it.
    onSecondaryClicked: calendar.toggleView()
    onScrolled: steps => calendar.step(steps > 0 ? -1 : 1)

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarText {
        text: Qt.formatDateTime(clock.date, "dd.MM.yyyy")
        font.family: Theme.monoFamily
        color: Theme.textPrimary
    }

    BarPopup {
        id: calendarPopup

        anchorItem: root
        alignRight: true

        // Opens on today rather than wherever it was left last time.
        onShownChanged: {
            if (calendarPopup.shown)
                calendar.reset();
        }

        Calendar {
            id: calendar

            // Built on the first open rather than at startup. Stepping and
            // switching views from the bar still work while it is empty: both
            // only move numbers the grid reads when it is there.
            active: calendarPopup.rendered
        }
    }
}
