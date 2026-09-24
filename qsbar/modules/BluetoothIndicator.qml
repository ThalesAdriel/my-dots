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

            // Font Awesome Free keeps bluetooth in Brands rather than Solid, so this is the one bar icon not drawn with IconText's family.
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

        warm: root.containsMouse

        // The brief read the indicator lives on lists nothing paired or nearby, so the panel used to open on a list it did not have yet and the devices grew in under a panel that was still sliding. Off the hover the list is already there; off `settled` at the latest, which is after the slide rather than during it.
        readonly property bool wantsDetail: bluetoothPopup.prepared || bluetoothPopup.settled

        onWantsDetailChanged: Bluetooth.detailed = bluetoothPopup.wantsDetail

        Loader {
            asynchronous: true
            active: bluetoothPopup.live

            sourceComponent: BluetoothPanel {
                // The list only animates its height once the panel is standing still.
                animated: bluetoothPopup.settled
            }
        }
    }

    BarTooltip {
        anchorItem: root
        shown: root.containsMouse && !bluetoothPopup.shown
        text: Bluetooth.summary
    }
}
