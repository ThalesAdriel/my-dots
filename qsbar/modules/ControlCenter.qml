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

    // The brightness row is left out entirely on a machine with no backlight.
    readonly property int brightnessRowHeight: Brightness.available ? 28 : 0
    readonly property int brightnessRowMargin: root.brightnessRowHeight > 0 ? 10 : 0

    // brightnessctl is only worth re-reading while the slider that shows it is on screen and the brightness keys could be moving it underneath.
    onSettledChanged: Brightness.watching = root.settled

    onShownChanged: {
        UiState.controlCenterOpen = root.shown;

        // Hiding the panel does not send the pointer anywhere.
        root.hoveredAction = null;

        // The list below already carries everything.
        if (root.shown)
            Notifications.clearPopups();
    }

    component ActionButton: Rectangle {
        id: action

        property string glyph: ""
        property string tooltip: ""
        property bool engaged: false

        // The header carries the same buttons at the size the Clear button next to them is.
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

    // Whichever action button the pointer is over, or null.
    property var hoveredAction: null

    Item {
        id: content

        implicitWidth: root.panelWidth
        implicitHeight: headerRow.height + brightnessRow.height + root.brightnessRowMargin + actionRow.height + listArea.height + buttonsCard.height + root.panelPadding * 4 + 10

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

                // The window opens over the middle of the screen.
                onTriggered: {
                    root.shown = false;
                    UiState.settingsOpen = true;
                }
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

        // The backlight, directly under System settings.
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

            // The same 32 wide slot the gear above and the bell below sit in.
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

                // The same gap the label and the slider above keep from their own icons.
                spacing: 10

                // Do not disturb reads as something you do to the list.
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

                // Newest first, and wrapped so an arriving or dismissed notification does not rebuild every card in the list.
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

                    // Through logind rather than at the locker directly, the same way scripts/power.sh does it.
                    onTriggered: Quickshell.execDetached(["loginctl", "lock-session"])
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

        // One tooltip for the whole action row, above whichever button is hovered, drawn inside the panel rather than as its own window.
        Item {
            id: actionTooltip

            // What the pointer is over and what the tooltip is drawing have to be separate.
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

            // Follows whichever button is hovered rather than sitting over the bottom row.
            y: {
                if (!actionTooltip.anchorButton)
                    return 0;

                const button = actionTooltip.anchorButton;
                const top = button.mapToItem(content, 0, 0).y;
                const above = top - actionTooltip.height - 8;
                return Math.round(above >= 0 ? above : top + button.height + 8);
            }

            visible: actionTooltip.shown || tooltipSurface.opacity > 0.01

            // The delay is per button, but only until one is on screen.
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
    }
}
