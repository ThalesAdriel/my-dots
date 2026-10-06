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

    // Through the calendar rather than straight at the setting.
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

        warm: root.containsMouse

        // Opens on today rather than wherever it was left last time.
        onShownChanged: {
            if (calendarPopup.shown)
                calendar.reset();
        }

        Calendar {
            id: calendar

            // Built when the pointer reaches the button rather than at startup.
            active: calendarPopup.live
        }
    }
}
