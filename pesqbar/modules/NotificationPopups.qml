pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/config"
import "root:/components"
import "root:/services"

// One surface for both toast styles. Only the placement and the card itself
// change between them: the timers, the lock that keeps a closed notification
// alive long enough to animate out, and the bookkeeping against the service are
// the same either way and live here once.
//
// Integrated is not a card that happens to sit under the bar. It is the bar
// carrying on downwards: same colour, touching the bar's bottom edge with no gap
// at all, and flared into it on both sides by the same quarter circle the bar
// uses at the corners of the screen. The toasts inside it share that one surface
// rather than each painting their own.
PanelWindow {
    id: root

    readonly property bool integrated: Settings.notificationStyle === "integrated"

    // Blur follows whichever surface the toast belongs to, so an integrated
    // block is blurred with the bar and a floating card with the panels.
    WlrLayershell.namespace: root.integrated ? Theme.barLayerNamespace : Theme.panelLayerNamespace

    readonly property int cardWidth: Settings.notificationWidth

    // The flare that joins the block to the bar, and the inset from the screen
    // edge that leaves room for the one on the right. Same setting the bar's own
    // corners follow, so switching outer corners off squares both off together.
    readonly property int fillet: root.integrated && Settings.outerCorners ? Settings.outerCornerRadius : 0

    // Same corner as the bell and the control centre it belongs to. The bar
    // already reserves its own height, so a top anchored layer starts right
    // below it: integrated touches that edge, floating stands off it.
    anchors {
        top: true
        right: true
    }

    margins.top: root.integrated ? 0 : 8
    margins.right: root.integrated ? 0 : 8

    exclusiveZone: 0
    color: "transparent"

    visible: Notifications.popups.length > 0
    implicitWidth: root.cardWidth + root.fillet * 2
    implicitHeight: Math.max(surface.implicitHeight, 1)

    // The block itself, inset from the screen edge by the width of its own
    // flare. Square along the top where it meets the bar, rounded at the bottom
    // where it ends.
    Item {
        id: surface

        anchors.right: parent.right
        anchors.rightMargin: root.fillet
        anchors.top: parent.top

        width: root.cardWidth
        implicitHeight: stack.implicitHeight

        Rectangle {
            anchors.fill: parent
            visible: root.integrated
            color: Theme.barBackground
            radius: Theme.cardRadius
        }

        // Covers the two top corners the radius above rounded off. They sit
        // against the bar, and a rounded corner there is the gap this whole
        // style exists to not have.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Theme.cardRadius
            visible: root.integrated && Theme.cardRadius > 0
            color: Theme.barBackground
        }

        Column {
            id: stack

            width: parent.width

            // Floating toasts are separate cards and stand apart; integrated
            // ones are one surface and must not.
            spacing: root.integrated ? 0 : 8

            Repeater {
                // A plain javascript array as a model rebuilds every delegate on
                // each change, which would restart the timer and replay the slide
                // in of every toast already on screen each time another arrives.
                model: ScriptModel {
                    values: Notifications.popups
                }

                delegate: Item {
                    id: wrapper

                    required property var modelData
                    required property int index

                    // 0 means it never times out on its own: critical urgency, or
                    // the app asked for that explicitly.
                    readonly property int timeout: Notifications.popupTimeout(wrapper.modelData)

                    property bool closing: false
                    property bool dismissOnFinish: false
                    property bool dropped: false

                    // Where the card comes in from. The floating card slides in
                    // off the right edge it is anchored to; the integrated one
                    // drops out from under the bar it hangs from.
                    readonly property real slideX: root.integrated ? 0 : wrapper.width
                    readonly property real slideY: root.integrated ? -14 : 0

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

                    // Holds the notification alive for as long as this toast
                    // exists. Without it the object is gone the instant it is
                    // closed, and the card animating out is left reading a
                    // destroyed object.
                    RetainableLock {
                        object: wrapper.modelData
                        locked: true

                        // The app withdrew it: slide the toast out rather than
                        // let it blink away, and do not close it again on the way.
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

                    // Both cards take the same properties and raise the same
                    // signal, so the style is a choice of component and nothing
                    // else.
                    Loader {
                        id: card

                        width: wrapper.width
                        x: wrapper.slideX
                        y: wrapper.slideY
                        opacity: 0

                        sourceComponent: root.integrated ? integratedCard : floatingCard
                    }

                    Component {
                        id: integratedCard

                        BarNotification {
                            notification: wrapper.modelData
                            width: wrapper.width
                            flat: true
                            onCloseRequested: wrapper.finish(true)
                        }
                    }

                    Component {
                        id: floatingCard

                        NotificationCard {
                            notification: wrapper.modelData
                            width: wrapper.width
                            onCloseRequested: wrapper.finish(true)
                        }
                    }

                    // One surface means nothing separates two stacked toasts, so
                    // a hairline does. Never above the first one, which meets the
                    // bar instead.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12

                        height: 1
                        visible: root.integrated && wrapper.index > 0
                        color: Qt.rgba(1, 1, 1, 0.08)
                        opacity: card.opacity
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
                            property: "y"
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
                            to: wrapper.slideX
                            duration: Theme.durationBase
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easingCurve
                        }
                        NumberAnimation {
                            target: card
                            property: "y"
                            to: wrapper.slideY
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

    // The two quarter circles that flare the block back out into the bar above
    // it, filled with the bar's own colour so the three read as one shape and the
    // background between them comes out rounded. Same component and the same
    // setting the bar uses at the corners of the screen.
    OuterCorner {
        anchors.right: surface.left
        anchors.top: surface.top

        size: root.fillet
        fillColor: Theme.barBackground
        centreRight: true
    }

    OuterCorner {
        anchors.left: surface.right
        anchors.top: surface.top

        size: root.fillet
        fillColor: Theme.barBackground
        centreRight: false
    }
}
