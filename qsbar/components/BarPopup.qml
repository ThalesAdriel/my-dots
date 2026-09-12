import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "root:/config"
import "root:/services"

// Welded to the bar, but a layer surface of its own rather than an xdg popup of it. Hyprland sends every popup down the live blur path and never lets one read the pre blurred background: renderLayer marks popups with popup = true, and SurfacePassElement answers that with needsLiveBlur true and needsPrecomputeBlur false whatever the layer's xray rule says. A blurred popup hanging off a blurred bar therefore blurs the framebuffer the bar is already painted into, and drags the bar's own pixels down into its top edge. On a layer of its own it takes the same namespace, and the same blur, as the toasts.
PanelWindow {
    id: root

    default property alias popupContent: contentHolder.data

    required property Item anchorItem
    property bool alignRight: false
    property int gap: 0
    property bool shown: false
    property bool dismissing: false
    property bool rendered: false
    property bool expanded: false
    property bool animating: false

    readonly property bool measured: contentHolder.implicitWidth > 0 && contentHolder.implicitHeight > 0

    // Room on either side of the panel for the fillets that weld it to the bar; the window grows outwards, so the panel itself stays where it was.
    readonly property int cornerSize: Settings.outerCorners ? Settings.outerCornerRadius : 0

    // Where the window sits along the bar. A layer surface is placed against the screen rather than against the button it belongs to, so the button's position has to be carried across by hand and kept up to date as the bar reflows.
    property real anchorOffset: 0

    function toggle(): void {
        if (root.dismissing)
            return;
        root.shown = !root.shown;
    }

    function beginEntrance(): void {
        if (root.expanded)
            return;
        root.animating = true;
        root.expanded = true;
    }

    function reposition(): void {
        if (!root.anchorItem)
            return;

        // The bar spans the screen from its left edge, so a position in its scene is already a position on the screen.
        const base = root.anchorItem.mapToItem(null, 0, 0).x;
        const align = root.alignRight ? root.anchorItem.width - root.implicitWidth : (root.anchorItem.width - root.implicitWidth) / 2;
        const rightmost = root.screen ? root.screen.width - root.implicitWidth : base + align;

        // A layer surface is placed in whole pixels, so the panel is rounded here rather than left to land between two.
        root.anchorOffset = Math.round(Math.max(Math.min(base + align, rightmost), 0));
    }

    // The screen the bar carrying the anchor is on, so a panel opens over the monitor it was asked from rather than over the first one.
    screen: {
        if (!root.anchorItem)
            return null;
        const barWindow = root.anchorItem.QsWindow.window;
        return barWindow ? barWindow.screen : null;
    }

    WlrLayershell.namespace: Theme.popupLayerNamespace

    // Only while something in a panel is waiting to be typed into, which today is the enterprise Wi-Fi form alone. The bar took this on behalf of the popups it carried; they are their own surfaces now and take it themselves.
    WlrLayershell.keyboardFocus: UiState.keyboardCapture ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // The bar already reserves its own height, so a top anchored layer starts right below it and the gap counts from that edge.
    anchors {
        top: true
        left: true
    }

    margins.top: root.gap
    margins.left: root.anchorOffset

    exclusiveZone: 0
    color: "transparent"

    implicitWidth: contentHolder.implicitWidth + root.cornerSize * 2
    implicitHeight: contentHolder.implicitHeight

    visible: root.rendered && root.measured

    // A panel is built on its first open, so its width only settles as it comes up; each of these lands before the surface is on screen.
    onImplicitWidthChanged: root.reposition()
    onScreenChanged: root.reposition()
    onShownChanged: {
        root.reposition();
        if (!root.shown)
            root.expanded = false;
    }

    data: [
        Connections {
            target: root.anchorItem

            function onXChanged(): void {
                root.reposition();
            }

            function onWidthChanged(): void {
                root.reposition();
            }
        },

        // The button also moves when the group holding it reflows, which is what a tray icon arriving or the drawer opening does to everything on its left.
        Connections {
            target: root.anchorItem ? root.anchorItem.parent : null

            function onXChanged(): void {
                root.reposition();
            }

            function onWidthChanged(): void {
                root.reposition();
            }
        },

        HyprlandFocusGrab {
            windows: [root]
            active: root.shown && root.visible
            onCleared: {
                root.shown = false;
                root.dismissing = true;
                dismissGuard.restart();
            }
        },

        Timer {
            id: dismissGuard
            interval: 200
            onTriggered: root.dismissing = false
        },

        Binding {
            target: root
            property: "rendered"
            value: true
            when: root.shown
            restoreMode: Binding.RestoreNone
        },

        FrameAnimation {
            id: entrance

            property int steadyFrames: 0
            property real lastTravel: NaN

            running: root.shown && root.visible && !root.expanded

            onRunningChanged: {
                entrance.steadyFrames = 0;
                entrance.lastTravel = NaN;
            }

            onTriggered: {
                if (surface.hiddenY !== entrance.lastTravel) {
                    entrance.lastTravel = surface.hiddenY;
                    entrance.steadyFrames = 0;
                    return;
                }

                if (++entrance.steadyFrames >= 1)
                    root.beginEntrance();
            }
        },

        Timer {
            interval: 250
            running: entrance.running
            onTriggered: root.beginEntrance()
        },

        Timer {
            interval: Theme.durationBase + 60
            running: !root.shown && root.rendered
            onTriggered: {
                root.rendered = false;
                root.animating = false;
            }
        },

        Item {
            id: clipper

            anchors.fill: parent
            clip: true

            Rectangle {
                id: surface

                // Welded to the bar, the panel's top corners are pushed up out of the clip so they come out square against it.
                readonly property int lift: root.cornerSize > 0 ? Theme.cardRadius : 0

                readonly property int hiddenY: -Math.max(surface.height, contentHolder.implicitHeight + surface.lift)

                x: root.cornerSize
                width: parent.width - root.cornerSize * 2
                height: parent.height + surface.lift
                y: root.expanded ? -surface.lift : surface.hiddenY

                color: Theme.popupBackground
                border.color: Theme.popupBorder
                border.width: Theme.panelBorderWidth
                radius: Theme.cardRadius

                Behavior on y {
                    enabled: root.animating

                    NumberAnimation {
                        duration: Theme.durationBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                }

                Item {
                    id: contentHolder

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: surface.lift
                    anchors.bottom: parent.bottom

                    implicitWidth: childrenRect.width
                    implicitHeight: childrenRect.height
                }
            }

            OuterCorner {
                x: 0
                y: surface.y + surface.lift

                size: root.cornerSize
                fillColor: Theme.popupBackground
                centreRight: true
            }

            OuterCorner {
                x: clipper.width - root.cornerSize
                y: surface.y + surface.lift

                size: root.cornerSize
                fillColor: Theme.popupBackground
                centreRight: false
            }
        }
    ]
}
