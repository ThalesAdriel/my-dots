pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"

Item {
    id: root

    // Set by whatever holds the calendar, and false until its popup has been opened once: the year view is twelve blocks of forty two day cells, around eighteen hundred items per screen, so nothing below the header exists until this goes true.
    property bool active: true

    property int offset: 0

    readonly property bool yearView: Settings.calendarYearView

    readonly property int padding: 16
    readonly property int columnGap: 14
    readonly property int rowGap: 16

    readonly property real monthBodyWidth: 36 * 7 + 34
    readonly property real monthBodyHeight: 30 * 7
    readonly property real yearBodyWidth: (17 * 7 + 26) * 3 + root.columnGap * 2
    readonly property real yearBodyHeight: (18 + 15 * 7) * 4 + root.rowGap * 3

    readonly property real bodyWidth: root.yearView ? root.yearBodyWidth : root.monthBodyWidth
    readonly property real bodyHeight: root.yearView ? root.yearBodyHeight : root.monthBodyHeight

    // Pulled out as plain numbers so the whole calendar does not rebuild on every clock tick: these only change when the day actually changes.
    readonly property int todayYear: clock.date.getFullYear()
    readonly property int todayMonth: clock.date.getMonth()
    readonly property int todayDay: clock.date.getDate()

    readonly property date anchorDate: {
        if (root.yearView)
            return new Date(root.todayYear + root.offset, 0, 1);
        return new Date(root.todayYear, root.todayMonth + root.offset, 1);
    }

    readonly property int firstWeekday: Qt.locale().firstDayOfWeek

    readonly property var weekdayNames: {
        const locale = Qt.locale();
        const first = root.firstWeekday;
        const names = [];
        for (let index = 0; index < 7; index++)
            names.push(locale.dayName((first + index) % 7, Locale.NarrowFormat));
        return names;
    }

    function isoWeek(date: var): int {
        const target = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        const dayNumber = (target.getDay() + 6) % 7;
        target.setDate(target.getDate() - dayNumber + 3);
        const firstThursday = new Date(target.getFullYear(), 0, 4);
        const firstDayNumber = (firstThursday.getDay() + 6) % 7;
        firstThursday.setDate(firstThursday.getDate() - firstDayNumber + 3);
        return 1 + Math.round((target.getTime() - firstThursday.getTime()) / 604800000);
    }

    function step(direction: int): void {
        root.offset += direction;
    }

    // An offset counts months in month view and years in year view, so it has to go back to today whenever the view changes or the calendar is reopened.
    function reset(): void {
        root.offset = 0;
    }

    function toggleView(): void {
        root.reset();
        Settings.calendarYearView = !Settings.calendarYearView;
    }

    implicitWidth: root.bodyWidth + root.padding * 2
    implicitHeight: header.height + root.bodyHeight + root.padding * 3

    // Nothing here animates: stepping a month redraws the grid on the spot and switching views swaps one layout for the other, so a fast scroll lands on the month it stopped at rather than chasing a cross fade.

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component MonthBlock: Item {
        id: block

        required property int year
        required property int monthIndex

        property real cellWidth: 17
        property real rowHeight: 15
        property real weekWidth: 26
        property real titleHeight: 18
        property real dayFontSize: 9

        readonly property date firstDay: new Date(block.year, block.monthIndex, 1)
        readonly property int lead: (block.firstDay.getDay() - root.firstWeekday + 7) % 7
        readonly property int dayCount: new Date(block.year, block.monthIndex + 1, 0).getDate()
        readonly property int rowCount: Math.ceil((block.lead + block.dayCount) / 7)

        width: block.cellWidth * 7 + block.weekWidth
        height: block.titleHeight + block.rowHeight * 7

        Text {
            id: blockTitle

            anchors.left: parent.left
            anchors.top: parent.top
            width: parent.width
            height: block.titleHeight
            verticalAlignment: Text.AlignVCenter

            visible: block.titleHeight > 1
            text: Qt.formatDate(block.firstDay, "MMMM")
            elide: Text.ElideRight
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightStrong
            font.capitalization: Font.Capitalize
        }

        Row {
            id: weekdayHeader

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: block.titleHeight

            Repeater {
                model: root.weekdayNames

                delegate: Text {
                    required property string modelData

                    width: block.cellWidth
                    height: block.rowHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: Theme.textMuted
                    font.family: Theme.sansFamily
                    font.pixelSize: block.dayFontSize
                }
            }
        }

        Grid {
            anchors.left: parent.left
            anchors.top: weekdayHeader.bottom
            columns: 7

            Repeater {
                model: 42

                delegate: Item {
                    id: dayCell

                    required property int index

                    readonly property int dayNumber: dayCell.index - block.lead + 1
                    readonly property bool inMonth: dayCell.dayNumber >= 1 && dayCell.dayNumber <= block.dayCount
                    readonly property bool isToday: dayCell.inMonth && block.year === root.todayYear && block.monthIndex === root.todayMonth && dayCell.dayNumber === root.todayDay

                    width: block.cellWidth
                    height: block.rowHeight
                    visible: dayCell.index < block.rowCount * 7

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(block.cellWidth, block.rowHeight) - 2
                        height: width
                        radius: Theme.squareCorners ? 0 : Math.min(Theme.radius, width / 2)
                        color: dayCell.isToday ? Theme.accent : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: dayCell.inMonth
                        text: dayCell.dayNumber
                        color: dayCell.isToday ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.monoFamily
                        font.pixelSize: block.dayFontSize
                        font.weight: dayCell.isToday ? Font.Bold : Font.Normal
                    }
                }
            }
        }

        Column {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: block.titleHeight + block.rowHeight

            Repeater {
                model: 6

                delegate: Text {
                    id: weekLabel

                    required property int index

                    width: block.weekWidth
                    height: block.rowHeight
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    visible: weekLabel.index < block.rowCount

                    text: {
                        const dayOfMonth = weekLabel.index * 7 - block.lead + 1;
                        const clamped = Math.min(Math.max(dayOfMonth, 1), block.dayCount);
                        const week = root.isoWeek(new Date(block.year, block.monthIndex, clamped));
                        return "W" + (week < 10 ? "0" + week : String(week));
                    }
                    color: Theme.textMuted
                    font.family: Theme.monoFamily
                    font.pixelSize: block.dayFontSize
                }
            }
        }
    }

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: 26

        BarButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 24
            leftPadding: 8
            rightPadding: 8
            onPrimaryClicked: root.step(-1)

            IconText {
                text: Glyphs.angleLeft
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        BarButton {
            anchors.centerIn: parent
            implicitHeight: 24
            leftPadding: 10
            rightPadding: 10

            doubleClickEnabled: true

            onPrimaryClicked: root.offset = 0
            onSecondaryClicked: root.toggleView()
            onDoubleClicked: root.toggleView()

            BarText {
                text: root.yearView ? String(root.anchorDate.getFullYear()) : Qt.formatDate(root.anchorDate, "MMMM yyyy")
                font.family: root.yearView ? Theme.monoFamily : Theme.sansFamily
                font.capitalization: Font.Capitalize
            }
        }

        BarButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: 24
            leftPadding: 8
            rightPadding: 8
            onPrimaryClicked: root.step(1)

            IconText {
                text: Glyphs.angleRight
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    Item {
        id: body

        anchors.top: header.bottom
        anchors.topMargin: root.padding
        anchors.horizontalCenter: parent.horizontalCenter

        width: root.bodyWidth
        height: root.bodyHeight
        clip: true

        // One layout at a time, and neither until the calendar is on screen; the body has a fixed size taken from plain numbers, so an empty loader does not collapse the panel.
        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            active: root.active && !root.yearView

            sourceComponent: MonthBlock {
                cellWidth: 36
                rowHeight: 30
                weekWidth: 34
                titleHeight: 0
                dayFontSize: 12

                year: root.anchorDate.getFullYear()
                monthIndex: root.anchorDate.getMonth()
            }
        }

        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            active: root.active && root.yearView

            sourceComponent: Grid {
                columns: 3
                columnSpacing: root.columnGap
                rowSpacing: root.rowGap

                Repeater {
                    model: 12

                    delegate: MonthBlock {
                        required property int index

                        year: root.anchorDate.getFullYear()
                        monthIndex: index
                    }
                }
            }
        }
    }

    // Sits over the whole calendar for the wheel and for the right click that switches views; left clicks are not accepted, so they fall through to the header buttons underneath.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        hoverEnabled: false

        onClicked: root.toggleView()

        onWheel: event => {
            if (event.angleDelta.y === 0)
                return;
            root.step(event.angleDelta.y > 0 ? -1 : 1);
        }
    }
}
