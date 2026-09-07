pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

BarPopup {
    id: root

    readonly property int panelPadding: 16
    readonly property int panelWidth: 400

    alignRight: true

    readonly property bool displaysVisible: root.shown && UiState.displaysOpen

    // hyprctl is only asked for the monitor layout while the sheet that shows
    // it is open.
    onDisplaysVisibleChanged: Displays.watching = root.displaysVisible

    // The brightness row is left out entirely on a machine with no backlight,
    // and the panel closes the gap rather than leaving an empty card behind.
    readonly property int brightnessRowHeight: Brightness.available ? 28 : 0
    readonly property int brightnessRowMargin: root.brightnessRowHeight > 0 ? 10 : 0

    onShownChanged: {
        UiState.controlCenterOpen = root.shown;

        // brightnessctl is only worth re-reading while the slider that shows it
        // is on screen and the brightness keys could be moving it underneath.
        Brightness.watching = root.shown;

        // Hiding the panel does not send the pointer anywhere, so nothing would
        // clear this on its own and the tooltip would be waiting on reopen.
        root.hoveredAction = null;

        // The list below already carries everything, so drop the toasts rather
        // than showing the same notifications twice.
        if (root.shown) {
            Notifications.clearPopups();
        } else {
            UiState.settingsOpen = false;
            UiState.displaysOpen = false;
        }
    }

    component ActionButton: Rectangle {
        id: action

        property string glyph: ""
        property string tooltip: ""
        property bool engaged: false

        // The header carries the same buttons at the size the Clear button next
        // to them is, rather than at the size of the row along the bottom.
        property bool compact: false

        signal triggered

        width: action.compact ? 32 : 44
        height: action.compact ? 28 : 44
        radius: Theme.radius
        color: {
            if (actionMouse.containsPress)
                return Theme.fillPressed;
            if (actionMouse.containsMouse)
                return Theme.fillHover;
            return action.engaged ? Theme.accent : Theme.fillTrack;
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }

        IconText {
            anchors.centerIn: parent
            fillBarHeight: false
            text: action.glyph
            font.pixelSize: action.compact ? Theme.fontSizeSmall : 17
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: action.triggered()

            onEntered: root.hoveredAction = action
            onExited: {
                if (root.hoveredAction === action)
                    root.hoveredAction = null;
            }
        }
    }

    // A sheet that covers the whole panel: a back arrow, a name, and whatever it
    // is showing, scrolling under them. Two of these stack, so the header and
    // the scrolling live here once rather than in each.
    component Sheet: Rectangle {
        id: sheet

        property string title: ""
        property bool open: false
        default property alias sheetContent: sheetHolder.data

        // What the content is loaded against: true while the sheet is open and
        // for as long as it is still fading out. Unloading on `open` alone
        // would empty the sheet under the fade.
        readonly property bool populated: sheet.open || sheet.opacity > 0.01

        signal dismissed

        anchors.fill: parent
        color: Theme.settingsBackground
        radius: Theme.cardRadius

        opacity: sheet.open ? 1 : 0
        visible: sheet.opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationBase
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
        }

        Item {
            id: sheetHeader

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.panelPadding
            height: 30

            Rectangle {
                id: sheetBack

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                width: 32
                height: 28
                radius: Theme.radius
                color: backMouse.containsPress ? Theme.fillPressed : backMouse.containsMouse ? Theme.fillHover : Theme.fillTrack

                IconText {
                    anchors.centerIn: parent
                    fillBarHeight: false
                    text: Glyphs.angleLeft
                    font.pixelSize: Theme.fontSizeSmall
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: sheet.dismissed()
                }
            }

            Text {
                anchors.left: sheetBack.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: sheet.title
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSize
            }
        }

        Flickable {
            anchors.top: sheetHeader.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: 10
            anchors.bottomMargin: root.panelPadding

            clip: true
            contentWidth: width
            contentHeight: sheetHolder.childrenRect.height
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: sheetHolder
                width: parent.width
                height: childrenRect.height
            }
        }
    }

    // Whichever action button the pointer is over, or null.
    property var hoveredAction: null

    Item {
        id: content

        implicitWidth: root.panelWidth
        implicitHeight: UiState.settingsOpen || UiState.displaysOpen ? 620 : headerRow.height + brightnessRow.height + root.brightnessRowMargin + actionRow.height + listArea.height + buttonsCard.height + root.panelPadding * 4 + 10

        Item {
            id: headerRow

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: root.panelPadding

            height: 28

            ActionButton {
                id: settingsButton

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                compact: true
                glyph: Glyphs.gear
                tooltip: "System settings"
                onTriggered: UiState.settingsOpen = true
            }

            Text {
                anchors.left: settingsButton.right
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                text: "System settings"
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }
        }

        // The backlight, directly under System settings: it is something you
        // reach for rather than read, so it sits at the top with the header
        // rather than down among the notifications. A bare row rather than a
        // Card: the header above it and the action row below are both drawn
        // straight onto the panel, and a filled block around this one alone
        // reads as a box that wandered in from somewhere else.
        Item {
            id: brightnessRow

            anchors.top: headerRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: root.brightnessRowMargin

            visible: root.brightnessRowHeight > 0
            height: root.brightnessRowHeight

            // The same 32 wide slot the gear above and the bell below sit in,
            // so the slider starts on the column the System settings label and
            // the Clear button already share rather than ten pixels left of it.
            IconText {
                id: brightnessIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                fillBarHeight: false
                width: 32
                text: Glyphs.sun
                color: Theme.textSecondary
            }

            LevelSlider {
                anchors.left: brightnessIcon.right
                anchors.leftMargin: 10
                anchors.right: brightnessValue.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                maximum: 100
                value: Brightness.level

                onMoved: newValue => Brightness.set(newValue)
            }

            Text {
                id: brightnessValue

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: 38
                horizontalAlignment: Text.AlignRight
                text: Brightness.level + "%"
                color: Theme.textSecondary
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Item {
            id: actionRow

            anchors.top: brightnessRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: 10

            height: 28

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                // The same gap the label and the slider above keep from their
                // own icons, so all three rows start their content on one column.
                spacing: 10

                // Do not disturb reads as something you do to the list, so it
                // sits with Clear rather than in the row of system actions.
                ActionButton {
                    compact: true
                    glyph: Notifications.doNotDisturb ? Glyphs.bellOff : Glyphs.bell
                    tooltip: Notifications.doNotDisturb ? "Do not disturb is on" : "Do not disturb"
                    engaged: Notifications.doNotDisturb
                    onTriggered: Notifications.doNotDisturb = !Notifications.doNotDisturb
                }

                Rectangle {
                    width: clearLabel.implicitWidth + 24
                    height: 28
                    radius: Theme.radius
                    color: clearMouse.containsPress ? Theme.fillPressed : clearMouse.containsMouse ? Theme.fillHover : Theme.fillTrack
                    opacity: Notifications.count > 0 ? 1 : 0.45

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear"
                        color: Theme.textPrimary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Notifications.count > 0
                        onClicked: Notifications.dismissAll()
                    }
                }
            }
        }

        Item {
            id: listArea

            anchors.top: actionRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: root.panelPadding

            height: Notifications.count === 0 ? 140 : Math.min(notificationList.contentHeight, 380)

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: Notifications.count === 0

                IconText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    fillBarHeight: false
                    text: Glyphs.comment
                    color: Theme.textMuted
                    font.pixelSize: 38
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No Notifications"
                    color: Theme.textMuted
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            ListView {
                id: notificationList

                anchors.fill: parent
                visible: Notifications.count > 0
                clip: true
                spacing: 10
                boundsBehavior: Flickable.StopAtBounds

                // Newest first, and wrapped so an arriving or dismissed
                // notification does not rebuild every card in the list.
                model: ScriptModel {
                    values: Notifications.history
                }

                delegate: NotificationCard {
                    required property var modelData

                    notification: modelData
                    width: notificationList.width

                    onCloseRequested: modelData.dismiss()
                }
            }
        }

        Card {
            id: buttonsCard

            anchors.top: listArea.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: root.panelPadding

            height: 68

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: (width - 44 * 4) / 3

                ActionButton {
                    glyph: Glyphs.lock
                    tooltip: "Lock"
                    onTriggered: Quickshell.execDetached(["hyprlock"])
                }

                ActionButton {
                    glyph: Glyphs.restart
                    tooltip: "Reboot"
                    onTriggered: Quickshell.execDetached(["reboot"])
                }

                ActionButton {
                    glyph: Glyphs.softRestart
                    tooltip: "Soft reboot"
                    onTriggered: Quickshell.execDetached(["systemctl", "soft-reboot"])
                }

                ActionButton {
                    glyph: Glyphs.power
                    tooltip: "Power off"
                    onTriggered: Quickshell.execDetached(["shutdown", "now"])
                }
            }
        }

        // One tooltip for the whole action row, sitting above whichever button
        // is hovered. Drawn inside the panel rather than as its own window: a
        // popup anchored to an item that is itself inside a popup is two levels
        // of xdg popup for a label that fits in the space above the buttons.
        Item {
            id: actionTooltip

            // What the pointer is over, and what the tooltip is drawing. They
            // have to be separate: the fade out outlives the pointer leaving, and
            // reading the live button on the way out collapsed the tooltip to an
            // empty box in the corner of the panel for the length of the fade.
            readonly property string target: root.hoveredAction ? root.hoveredAction.tooltip : ""

            property var anchorButton: null
            property string label: ""
            property bool shown: false

            width: tooltipSurface.width
            height: tooltipSurface.height

            x: {
                if (!actionTooltip.anchorButton)
                    return 0;

                const button = actionTooltip.anchorButton;
                const centre = button.mapToItem(content, button.width / 2, 0).x;
                const free = content.width - actionTooltip.width - root.panelPadding;
                return Math.round(Math.min(Math.max(centre - actionTooltip.width / 2, root.panelPadding), free));
            }

            // Follows whichever button is hovered rather than sitting over the
            // bottom row: the gear and the do not disturb bell are up in the
            // header now, where there is nothing above them to sit in, so the
            // label drops below a button that has no room over it.
            y: {
                if (!actionTooltip.anchorButton)
                    return 0;

                const button = actionTooltip.anchorButton;
                const top = button.mapToItem(content, 0, 0).y;
                const above = top - actionTooltip.height - 8;
                return Math.round(above >= 0 ? above : top + button.height + 8);
            }

            visible: actionTooltip.shown || tooltipSurface.opacity > 0.01

            // The delay is per button, but only until one is on screen: once it
            // is, sliding along the row swaps the label straight away rather
            // than making you wait again at every button.
            onTargetChanged: {
                if (actionTooltip.target === "") {
                    delayTimer.stop();
                    actionTooltip.shown = false;
                    return;
                }

                actionTooltip.anchorButton = root.hoveredAction;
                actionTooltip.label = actionTooltip.target;

                if (!actionTooltip.shown)
                    delayTimer.restart();
            }

            Behavior on x {
                enabled: actionTooltip.shown
                NumberAnimation {
                    duration: Theme.durationFast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }

            Behavior on y {
                enabled: actionTooltip.shown
                NumberAnimation {
                    duration: Theme.durationFast
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }

            Timer {
                id: delayTimer

                interval: 450
                onTriggered: actionTooltip.shown = actionTooltip.target !== ""
            }

            Rectangle {
                id: tooltipSurface

                width: tooltipLabel.implicitWidth + 20
                height: tooltipLabel.implicitHeight + 12

                color: Theme.popupBackground
                border.color: Theme.popupBorder
                border.width: Theme.panelBorderWidth
                radius: Theme.radius

                opacity: actionTooltip.shown ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durationFast
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                }

                Text {
                    id: tooltipLabel

                    anchors.centerIn: parent
                    text: actionTooltip.label
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // Both sheets are built on first use rather than at startup. Between
        // them they are the two largest trees in the shell, they are two clicks
        // deep, and there is one of each per output: nothing here is worth
        // constructing for a session that never opens settings.
        Sheet {
            id: settingsSheet

            title: "System settings"

            // Only one sheet is on screen: opening the display manager fades
            // this one out under it rather than leaving both to render.
            open: UiState.settingsOpen && !UiState.displaysOpen
            onDismissed: UiState.settingsOpen = false

            Loader {
                width: parent.width
                active: settingsSheet.populated

                sourceComponent: SettingsPanel {}
            }
        }

        Sheet {
            id: displaysSheet

            title: "Display manager"

            open: UiState.displaysOpen
            onDismissed: UiState.displaysOpen = false

            Loader {
                width: parent.width
                active: displaysSheet.populated

                sourceComponent: DisplayManager {}
            }
        }
    }
}
