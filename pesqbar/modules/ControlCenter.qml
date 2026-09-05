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

    onShownChanged: {
        UiState.controlCenterOpen = root.shown;

        // Hiding the panel does not send the pointer anywhere, so nothing would
        // clear this on its own and the tooltip would be waiting on reopen.
        root.hoveredAction = null;

        // The list below already carries everything, so drop the toasts rather
        // than showing the same notifications twice.
        if (root.shown)
            Notifications.clearPopups();
        else
            UiState.settingsOpen = false;
    }

    component ActionButton: Rectangle {
        id: action

        property string glyph: ""
        property string tooltip: ""
        property bool engaged: false

        signal triggered

        width: 44
        height: 44
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
            font.pixelSize: 17
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
        implicitHeight: UiState.settingsOpen ? 620 : (musicCard.visible ? musicCard.height + root.panelPadding : 0) + titleRow.height + listArea.height + buttonsCard.height + root.panelPadding * 4

        MusicCard {
            id: musicCard

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.panelPadding
        }

        Item {
            id: titleRow

            anchors.top: musicCard.visible ? musicCard.bottom : parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: root.panelPadding

            height: 32

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSize
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 32
                    height: 28
                    radius: Theme.radius
                    color: gearMouse.containsPress ? Theme.fillPressed : gearMouse.containsMouse ? Theme.fillHover : Theme.fillTrack

                    IconText {
                        anchors.centerIn: parent
                        fillBarHeight: false
                        text: Glyphs.gear
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    MouseArea {
                        id: gearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: UiState.settingsOpen = true
                    }
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

            anchors.top: titleRow.bottom
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
                spacing: (width - 44 * 5) / 4

                ActionButton {
                    glyph: Notifications.doNotDisturb ? Glyphs.bellOff : Glyphs.bell
                    tooltip: Notifications.doNotDisturb ? "Do not disturb is on" : "Do not disturb"
                    engaged: Notifications.doNotDisturb
                    onTriggered: Notifications.doNotDisturb = !Notifications.doNotDisturb
                }

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
            y: buttonsCard.y - actionTooltip.height - 8

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

        Rectangle {
            id: settingsOverlay

            anchors.fill: parent
            color: Theme.settingsBackground
            radius: Theme.cardRadius

            opacity: UiState.settingsOpen ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }

            Item {
                id: settingsHeader

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: root.panelPadding
                height: 30

                Rectangle {
                    id: backButton

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
                        onClicked: UiState.settingsOpen = false
                    }
                }

                Text {
                    anchors.left: backButton.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bar settings"
                    color: Theme.textSecondary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            Flickable {
                anchors.top: settingsHeader.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.panelPadding
                anchors.rightMargin: root.panelPadding
                anchors.topMargin: 10
                anchors.bottomMargin: root.panelPadding

                clip: true
                contentWidth: width
                contentHeight: settingsPanel.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                SettingsPanel {
                    id: settingsPanel
                    width: parent.width
                }
            }
        }
    }
}
