import QtQuick
import Quickshell.Services.UPower
import qs.config

// Lightweight UPower battery indicator, only visible when a battery is present.
Rectangle {
    id: root

    property var device: UPower.displayDevice

    // Check both laptop flag and percentage rather than trusting the laptop flag alone.
    property bool present: !!root.device && root.device.ready === true && (root.device.isLaptopBattery === true || root.device.percentage > 0)
    property int percent: root.present ? Math.round(root.device.percentage * 100) : 0
    property bool charging: root.present && (root.device.state === UPowerDeviceState.Charging || root.device.state === UPowerDeviceState.PendingCharge)
    readonly property bool low: root.present && !root.charging && root.percent <= 20

    readonly property string glyph: {
        if (root.charging)
            return "\uf0e7";
        if (root.percent >= 88)
            return "\uf240";
        if (root.percent >= 63)
            return "\uf241";
        if (root.percent >= 38)
            return "\uf242";
        if (root.percent >= 13)
            return "\uf243";
        return "\uf244";
    }

    visible: root.present
    implicitWidth: content.implicitWidth + 24
    implicitHeight: 38
    radius: Config.radius(Config.rounding, height)
    color: Config.card
    border.width: Config.outlineThickness
    border.color: root.low ? Config.fail : "transparent"

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: root.glyph
            color: root.charging ? Config.caps : root.low ? Config.fail : Config.line
            font.family: Config.iconFamily
            font.weight: Font.Black
            font.pixelSize: Config.textSize
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: root.charging ? root.percent + "% Charging" : root.percent + "%"
            color: Config.text
            font.family: Config.fontFamily
            font.pixelSize: Config.textSize
        }
    }
}
