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

    // Night light can be hidden from Control Center in Bar settings.
    readonly property int nightLightRowHeight: Settings.showNightLight ? 28 : 0
    readonly property int nightLightRowMargin: root.nightLightRowHeight > 0 ? 10 : 0

    // Power profile pills are left out when disabled in settings or when power-profiles-daemon is unavailable.
    readonly property int powerRowHeight: Settings.showPowerProfiles && PowerProfiles.available && PowerProfiles.profiles.length > 0 ? 28 : 0
    readonly property int powerRowMargin: root.powerRowHeight > 0 ? 10 : 0

    readonly property bool hasQuickControls: root.brightnessRowHeight > 0 || root.nightLightRowHeight > 0 || root.powerRowHeight > 0

    // brightnessctl is only worth re-reading while the slider that shows it is on screen and the brightness keys could be moving it underneath.
    onSettledChanged: Brightness.watching = root.settled

    onShownChanged: {
        UiState.controlCenterOpen = root.shown;

        // Hiding the panel does not send the pointer anywhere.
        root.hoveredAction = null;

        // The list below already carries everything.
        if (root.shown) {
            Notifications.clearPopups();
            if (Settings.showPowerProfiles)
                PowerProfiles.refresh();
        }
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

        readonly property int controlsCardHeight: root.hasQuickControls ? (controlsColumn.implicitHeight + 24) : 0
        readonly property int controlsCardMargin: root.hasQuickControls ? 12 : 0

        implicitWidth: root.panelWidth
        implicitHeight: headerRow.height + content.controlsCardHeight + content.controlsCardMargin + actionRow.height + listArea.height + buttonsCard.height + root.panelPadding * 4 + 12

        Item {
            id: headerRow

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: root.panelPadding

            height: 28

            Text {
                anchors.left: parent.left
                anchors.right: settingsPill.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                text: "Control Center"
                color: Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeightStrong
                elide: Text.ElideRight
            }

            Rectangle {
                id: settingsPill

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: settingsRow.implicitWidth + 18
                height: 28
                radius: Theme.radius
                color: settingsPillMouse.containsPress ? Theme.fillPressed : (settingsPillMouse.containsMouse ? Theme.fillHover : Theme.fillTrack)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }

                Row {
                    id: settingsRow

                    anchors.centerIn: parent
                    spacing: 6

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        fillBarHeight: false
                        text: Glyphs.gear
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Settings"
                        color: Theme.textPrimary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                MouseArea {
                    id: settingsPillMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.shown = false;
                        UiState.settingsOpen = true;
                    }
                }
            }
        }

        // Quick controls card: brightness, night light, and power profiles grouped cleanly.
        Card {
            id: controlsCard

            anchors.top: headerRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: content.controlsCardMargin

            visible: root.hasQuickControls
            height: content.controlsCardHeight

            Column {
                id: controlsColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                Item {
                    id: brightnessRow

                    width: parent.width
                    visible: root.brightnessRowHeight > 0
                    height: root.brightnessRowHeight

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

                        width: 42
                        horizontalAlignment: Text.AlignRight
                        text: Brightness.level + "%"
                        color: Theme.textSecondary
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Item {
                    id: nightLightRow

                    width: parent.width
                    visible: root.nightLightRowHeight > 0
                    height: root.nightLightRowHeight

                    ActionButton {
                        id: nightLightButton

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        compact: true
                        glyph: Glyphs.moon
                        tooltip: NightLight.enabled ? "Night light is on (" + NightLight.temperature + "K)" : "Night light"
                        engaged: NightLight.enabled
                        onTriggered: NightLight.toggle()
                    }

                    LevelSlider {
                        anchors.left: nightLightButton.right
                        anchors.leftMargin: 10
                        anchors.right: nightLightValue.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter

                        maximum: NightLight.maxTemperature - NightLight.minTemperature
                        value: NightLight.temperature - NightLight.minTemperature
                        fillColor: NightLight.enabled ? Theme.accent : Theme.textMuted
                        opacity: NightLight.enabled ? 1 : 0.45

                        onMoved: newValue => NightLight.setTemperature(NightLight.minTemperature + newValue)
                    }

                    Text {
                        id: nightLightValue

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        width: 42
                        horizontalAlignment: Text.AlignRight
                        text: NightLight.temperature + "K"
                        color: NightLight.enabled ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }

                Item {
                    id: powerRow

                    width: parent.width
                    visible: root.powerRowHeight > 0
                    height: root.powerRowHeight

                    Row {
                        id: powerButtons

                        anchors.fill: parent
                        spacing: 6

                        Repeater {
                            model: PowerProfiles.sortedProfiles

                            delegate: PanelButton {
                                id: profilePill

                                required property string modelData

                                width: (powerButtons.width - powerButtons.spacing * Math.max(PowerProfiles.sortedProfiles.length - 1, 0)) / Math.max(PowerProfiles.sortedProfiles.length, 1)
                                height: powerRow.height
                                label: PowerProfiles.label(profilePill.modelData)
                                accented: PowerProfiles.active === profilePill.modelData
                                onActivated: PowerProfiles.set(profilePill.modelData)
                            }
                        }
                    }
                }
            }
        }

        // Notifications section header: title on the left, Do Not Disturb + Clear on the right.
        Item {
            id: actionRow

            anchors.top: controlsCard.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.panelPadding
            anchors.rightMargin: root.panelPadding
            anchors.topMargin: 12

            height: 28

            Text {
                anchors.left: parent.left
                anchors.right: notifActions.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                text: Notifications.count > 0 ? ("Notifications · " + Notifications.count) : "Notifications"
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightStrong
                elide: Text.ElideRight
            }

            Row {
                id: notifActions

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                ActionButton {
                    compact: true
                    glyph: Notifications.doNotDisturb ? Glyphs.bellOff : Glyphs.bell
                    tooltip: Notifications.doNotDisturb ? "Do not disturb is on" : "Do not disturb"
                    engaged: Notifications.doNotDisturb
                    onTriggered: Notifications.doNotDisturb = !Notifications.doNotDisturb
                }

                Rectangle {
                    width: clearLabel.implicitWidth + 20
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
