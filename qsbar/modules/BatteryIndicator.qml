import QtQuick
import Quickshell.Services.UPower
import "root:/config"
import "root:/components"
import "root:/services"

// The one module that needs Quickshell.Services.UPower, reached through a Loader in the bar so a Quickshell built without it costs this module and nothing else.
BarButton {
    id: root

    readonly property var device: UPower.displayDevice

    // The percentage is the second half of the test rather than trusting the laptop flag alone: a desktop's display device is ready and reports 0, so a machine with no battery still comes out empty handed while a real battery is not lost.
    readonly property bool present: !!root.device && root.device.ready === true && (root.device.isLaptopBattery === true || root.device.percentage > 0)
    readonly property real level: root.present ? root.device.percentage : 0
    readonly property int percent: Math.round(root.level * 100)
    readonly property int state: root.present ? root.device.state : UPowerDeviceState.Unknown

    readonly property bool charging: root.state === UPowerDeviceState.Charging || root.state === UPowerDeviceState.PendingCharge
    readonly property bool full: root.state === UPowerDeviceState.FullyCharged
    readonly property bool low: root.present && !root.charging && !root.full && root.level <= 0.15

    // Five glyphs across the range, so each covers a quarter with the ends taking half a step: 0% is empty, 100% is full, and nothing in between overstates what is left.
    readonly property string levelGlyph: Glyphs.batteryLevels[Math.min(Math.max(Math.round(root.level * 4), 0), 4)]

    // The badge over the battery, the way the reference sheet draws them: a bolt while charging, a plug once done, a cross when there is no battery to report on.
    readonly property string badge: {
        if (!root.present)
            return Glyphs.xmark;
        if (root.charging)
            return Glyphs.bolt;
        if (root.full)
            return Glyphs.plug;
        if (root.low)
            return Glyphs.triangleExclamation;
        return "";
    }

    readonly property color badgeColor: {
        if (!root.present)
            return Theme.textMuted;
        if (root.low)
            return Theme.urgent;
        return Theme.accent;
    }

    readonly property string stateLabel: {
        if (!root.present)
            return "No battery";
        if (root.charging)
            return "Charging";
        if (root.full)
            return "Fully charged";
        return "On battery";
    }

    function duration(seconds: int): string {
        if (seconds <= 0)
            return "";

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round((seconds % 3600) / 60);

        if (hours > 0)
            return hours + " h " + minutes + " min";
        return minutes + " min";
    }

    readonly property string timeLabel: {
        if (!root.present)
            return "";
        if (root.charging)
            return root.duration(root.device.timeToFull);
        if (root.full)
            return "";
        return root.duration(root.device.timeToEmpty);
    }

    highlighted: batteryPopup.shown
    onPrimaryClicked: batteryPopup.toggle()

    IconStack {
        IconText {
            anchors.centerIn: parent
            text: root.levelGlyph
            color: {
                if (!root.present)
                    return Theme.textMuted;
                return root.low ? Theme.urgent : Theme.textPrimary;
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }

        // Sits inside the battery body rather than centred on the glyph: the terminal nub is on the right, so the middle of the outline is a little left of the middle of the character.
        IconText {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -1

            visible: root.badge !== ""
            text: root.badge
            color: root.badgeColor
            font.pixelSize: Math.max(Math.round(Theme.iconSize * 0.55), 7)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }
    }

    BarPopup {
        id: batteryPopup

        anchorItem: root
        alignRight: true

        // The profile list is only re-read while the panel is up; nothing else in the shell shows it.
        onShownChanged: PowerProfiles.detailed = batteryPopup.shown

        Loader {
            asynchronous: true
            active: batteryPopup.rendered

            sourceComponent: BatteryPanel {
                present: root.present
                level: root.level
                percent: root.percent
                stateLabel: root.stateLabel
                timeLabel: root.timeLabel
                low: root.low
                charging: root.charging
                health: root.present ? Math.round(root.device.healthPercentage) : 0
            }
        }
    }

    BarTooltip {
        anchorItem: root
        shown: root.containsMouse && !batteryPopup.shown
        text: {
            if (!root.present)
                return "No battery";
            const remaining = root.timeLabel !== "" ? ", " + root.timeLabel : "";
            return root.percent + "%, " + root.stateLabel.toLowerCase() + remaining;
        }
    }
}
