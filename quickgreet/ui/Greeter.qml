import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// One window per output, each with the background and the animation layer.
Scope {
    id: root

    // For the test harness, which reaches into them.
    readonly property alias windows: variants.instances

    // Follow whichever monitor the user interacts with; fall back if that screen disappears.
    property var activeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property var effectiveScreen: (root.activeScreen && Quickshell.screens.indexOf(root.activeScreen) !== -1) ? root.activeScreen : (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)

    Connections {
        target: Quickshell

        function onScreensChanged() {
            if (!root.activeScreen || Quickshell.screens.indexOf(root.activeScreen) === -1)
                root.activeScreen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        }
    }

    Variants {
        id: variants

        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            readonly property bool main: window.modelData === root.effectiveScreen

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

            // Passive sensor on non-active monitors: hovering or clicking moves the login surface here.
            MouseArea {
                anchors.fill: parent
                visible: Config.followPointer && !window.main
                enabled: Config.followPointer && !window.main
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons

                onEntered: root.activeScreen = window.modelData
                onPositionChanged: root.activeScreen = window.modelData
                onPressed: root.activeScreen = window.modelData
            }
        }
    }
}
