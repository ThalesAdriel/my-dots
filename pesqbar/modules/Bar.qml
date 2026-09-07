import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root

    WlrLayershell.namespace: Theme.barLayerNamespace

    // The bar takes no keyboard at all unless something in a panel is waiting to
    // be typed into, which today is only the enterprise Wi-Fi form. Left on
    // OnDemand permanently, every click anywhere on the bar would pull focus off
    // the window in front of it.
    WlrLayershell.keyboardFocus: UiState.keyboardCapture ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // A layer surface is handed its namespace when the compositor creates it and
    // the protocol has no request to rename one, so the name Hyprland matches its
    // blur rules against is frozen for the life of the window. Flipping a blur
    // switch has to throw the window away and ask for it again. Toasts and the
    // identify overlay come and go on their own and pick the new name up by
    // themselves; the bar is up from login to logout and never would.
    visible: !namespaceReload.running

    required property var modelData

    // The fillets hang below the bar, so the window is taller than the bar
    // while still only reserving the bar's own height from the compositor.
    readonly property int cornerSize: Settings.outerCorners ? Settings.outerCornerRadius : 0

    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight + root.cornerSize
    exclusiveZone: Theme.barHeight
    color: "transparent"

    // Only the bar itself takes input. The fillets sit over the desktop.
    mask: Region {
        item: barArea
    }

    Timer {
        id: namespaceReload

        interval: 1
    }

    Connections {
        target: Theme

        function onBarLayerNamespaceChanged(): void {
            namespaceReload.restart();
        }
    }

    Item {
        id: barArea

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        height: Theme.barHeight

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right

            y: -Settings.barRadius
            height: parent.height + Settings.barRadius
            radius: Settings.barRadius
            color: Theme.barBackground
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            visible: Settings.showTopBorder
            color: Theme.barBorder
        }

        Row {
            id: leftGroup

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6
            spacing: Theme.moduleSpacing
            opacity: 0

            Workspaces {
            }

            WindowTitle {
            }
        }

        Clock {
            id: centerGroup

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6
            opacity: 0
        }

        Row {
            id: rightGroup

            anchors.right: parent.right
            anchors.rightMargin: 5
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -6
            spacing: Theme.moduleSpacing
            opacity: 0

            TrayDrawer {
            }

            Loader {
                active: Settings.showRecording && Recording.active
                visible: active
                source: "root:/modules/RecordingIndicator.qml"
            }

            IdleToggle {
            }

            Volume {
            }

            NotificationBell {
            }

            // The remaining optional modules, off until they are switched on in
            // bar settings. Through a Loader rather than a visible binding:
            // nothing is compiled or polled while a module is off, and a
            // Quickshell missing UPower costs the battery module alone rather
            // than the bar.
            Loader {
                active: Settings.showNetwork
                visible: active
                source: "root:/modules/NetworkIndicator.qml"
            }

            Loader {
                active: Settings.showBluetooth
                visible: active
                source: "root:/modules/BluetoothIndicator.qml"
            }

            Loader {
                active: Settings.showBattery
                visible: active
                source: "root:/modules/BatteryIndicator.qml"
            }

            DateField {
            }
        }
    }

    OuterCorner {
        anchors.left: parent.left
        anchors.top: barArea.bottom

        size: root.cornerSize
        fillColor: Theme.barBackground
        centreRight: false
    }

    OuterCorner {
        anchors.right: parent.right
        anchors.top: barArea.bottom

        size: root.cornerSize
        fillColor: Theme.barBackground
        centreRight: true
    }

    component EntranceAnimation: SequentialAnimation {
        required property Item item
        required property int delay

        running: true

        PauseAnimation {
            duration: delay
        }

        ParallelAnimation {
            NumberAnimation {
                target: item
                property: "opacity"
                to: 1
                duration: Theme.durationSlow
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
            NumberAnimation {
                target: item
                property: "anchors.verticalCenterOffset"
                to: 0
                duration: Theme.durationSlow
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
        }
    }

    EntranceAnimation {
        item: leftGroup
        delay: 0
    }

    EntranceAnimation {
        item: centerGroup
        delay: 90
    }

    EntranceAnimation {
        item: rightGroup
        delay: 180
    }
}
