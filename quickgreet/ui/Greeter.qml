import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// One window per output, each with the background and the animation layer.
Scope {
    // For the test harness, which reaches into them.
    readonly property alias windows: variants.instances

    Variants {
        id: variants

        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            readonly property bool main: window.modelData === Quickshell.screens[0]

            screen: window.modelData
            color: Config.backgroundColor

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickgreet"
            WlrLayershell.keyboardFocus: window.main ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Backdrop {
                anchors.fill: parent
            }

            Loader {
                anchors.fill: parent
                active: Config.animation !== "none"
                sourceComponent: AsciiLayer {}
            }

            Loader {
                anchors.fill: parent
                active: window.main
                focus: true
                sourceComponent: Surface {}
            }
        }
    }
}
