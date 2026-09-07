import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

BarButton {
    id: root

    highlighted: networkPopup.shown

    onPrimaryClicked: networkPopup.toggle()
    onSecondaryClicked: {
        if (Network.available)
            Network.setWifiRadio(!Network.wifiRadio);
    }

    IconStack {
        IconText {
            anchors.centerIn: parent

            // A cable beats a radio: with both up the wire is what traffic is
            // actually going over, and that is what the bar should be saying.
            text: Network.wired ? Glyphs.networkWired : Glyphs.wifi
            color: {
                if (!Network.available)
                    return Theme.textMuted;
                if (Network.connected)
                    return Theme.textPrimary;
                return Theme.textMuted;
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

    // Signal strength as the same hairline the volume module draws, rather than
    // as a graded wifi glyph. The graded ones are not in every build of Font
    // Awesome Free, and a missing glyph reads as a box, not as a weak signal.
    overlayContent: Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4

        width: parent.width - 10
        height: 2
        radius: Theme.pill(2)
        color: Theme.fillTrack

        opacity: Network.wifiConnected && !Network.wired ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationBase
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top

            height: parent.height
            radius: parent.radius
            width: parent.width * Math.min(Math.max(Network.signalStrength / 100, 0), 1)
            color: Network.signalStrength < 35 ? Theme.urgent : Theme.accent

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }
    }

    BarPopup {
        id: networkPopup

        anchorItem: root
        alignRight: true

        // The access point list and the saved profiles are only read while this
        // is open, and the poll slows back down when it closes.
        onShownChanged: {
            Network.detailed = networkPopup.shown;
            if (networkPopup.shown)
                Network.rescan();
            else if (panelLoader.item)
                panelLoader.item.reset();
        }

        Loader {
            id: panelLoader

            active: networkPopup.rendered

            sourceComponent: NetworkPanel {}
        }
    }

    BarTooltip {
        anchorItem: root
        shown: root.containsMouse && !networkPopup.shown
        text: Network.summary
    }
}
