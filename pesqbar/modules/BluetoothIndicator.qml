import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

BarButton {
    id: root

    highlighted: bluetoothPopup.shown

    onPrimaryClicked: bluetoothPopup.toggle()
    onSecondaryClicked: {
        if (Bluetooth.available)
            Bluetooth.setPowered(!Bluetooth.powered);
    }

    IconStack {
        Text {
            anchors.centerIn: parent
            height: Theme.barHeight
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter

            // Font Awesome Free keeps bluetooth in Brands rather than in Solid,
            // so this is the one icon in the bar that is not drawn with
            // IconText's family.
            text: Glyphs.bluetooth
            font.family: Theme.brandFamily
            font.pixelSize: Theme.iconSize + 1

            color: {
                if (!Bluetooth.available || !Bluetooth.powered)
                    return Theme.textMuted;
                return Bluetooth.anyConnected ? Theme.accent : Theme.textPrimary;
            }

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
        id: bluetoothPopup

        anchorItem: root
        alignRight: true

        onShownChanged: Bluetooth.detailed = bluetoothPopup.shown

        Loader {
            active: bluetoothPopup.rendered

            sourceComponent: BluetoothPanel {}
        }
    }

    BarTooltip {
        anchorItem: root
        shown: root.containsMouse && !bluetoothPopup.shown
        text: Bluetooth.summary
    }
}
