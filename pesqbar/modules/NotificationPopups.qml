pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root

    WlrLayershell.namespace: Theme.panelLayerNamespace

    readonly property int cardWidth: 340

    anchors {
        top: true
        right: true
    }

    margins.top: 8
    margins.right: 8

    exclusiveZone: 0
    color: "transparent"

    visible: Notifications.popups.length > 0
    implicitWidth: root.cardWidth
    implicitHeight: Math.max(stack.implicitHeight, 1)

    Column {
        id: stack

        width: parent.width
        spacing: 8

        Repeater {
            // A plain javascript array as a model rebuilds every delegate on
            // each change, which would restart the timer and replay the slide in
            // of every toast already on screen each time another one arrives.
            model: ScriptModel {
                values: Notifications.popups
            }

            delegate: Item {
                id: wrapper

                required property var modelData

                // 0 means it never times out on its own: critical urgency, or the
                // app asked for that explicitly.
                readonly property int timeout: Notifications.popupTimeout(wrapper.modelData)

                property bool closing: false
                property bool dismissOnFinish: false
                property bool dropped: false

                function finish(dismiss: bool): void {
                    if (wrapper.closing)
                        return;
                    wrapper.dismissOnFinish = dismiss;
                    wrapper.closing = true;
                    removeTimer.start();
                }

                width: stack.width
                height: wrapper.closing ? 0 : card.implicitHeight
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durationBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                }

                HoverHandler {
                    id: hover
                }

                // Holds the notification alive for as long as this toast exists.
                // Without it the object is gone the instant it is closed, and the
                // card animating out is left reading a destroyed object.
                RetainableLock {
                    object: wrapper.modelData
                    locked: true

                    // The app withdrew it: slide the toast out rather than let it
                    // blink away, and do not close it a second time on the way.
                    onDropped: {
                        wrapper.dropped = true;
                        wrapper.finish(false);
                    }
                }

                Timer {
                    interval: Math.max(wrapper.timeout, 1)
                    running: wrapper.timeout > 0 && !wrapper.closing && !hover.hovered
                    onTriggered: wrapper.finish(false)
                }

                Timer {
                    id: removeTimer

                    interval: Theme.durationBase
                    onTriggered: {
                        const notification = wrapper.modelData;

                        if (wrapper.dropped)
                            Notifications.removePopup(notification);
                        else if (wrapper.dismissOnFinish)
                            Notifications.close(notification);
                        else
                            Notifications.releasePopup(notification);
                    }
                }

                NotificationCard {
                    id: card

                    notification: wrapper.modelData
                    width: wrapper.width
                    x: wrapper.width
                    opacity: 0

                    onCloseRequested: wrapper.finish(true)
                }

                Component.onCompleted: entrance.start()
                onClosingChanged: {
                    if (wrapper.closing)
                        exit.start();
                }

                ParallelAnimation {
                    id: entrance

                    NumberAnimation {
                        target: card
                        property: "x"
                        to: 0
                        duration: Theme.durationSlow
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        to: 1
                        duration: Theme.durationSlow
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                }

                ParallelAnimation {
                    id: exit

                    NumberAnimation {
                        target: card
                        property: "x"
                        to: wrapper.width
                        duration: Theme.durationBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        to: 0
                        duration: Theme.durationBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                }
            }
        }
    }
}
