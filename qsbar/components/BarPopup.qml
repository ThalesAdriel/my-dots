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

    // Set from the hover state of the button. A panel's first build is its most expensive frame, and the pointer arrives before the click, so the build goes there rather than onto the slide.
    property bool warm: false

    // Whether the content exists, as against `rendered`, which is whether the panel is open. Only the item tree is built early; everything worth watching stays on `rendered`.
    property bool prepared: false

    readonly property bool live: root.rendered || root.prepared

    // True while the panel is moving, and the reason the surface size is held still below.
    property bool sliding: false

    // True from the frame the panel lands to the frame it is asked to close: for work worth doing while open but not on the frame the slide starts.
    property bool settled: false

    // The size the panel is committed to, which is not the size of what is in it: content settles over several frames and sometimes over a second, and a panel that adopted every step of that would change shape halfway through its slide. The width is the window's too; the height is only the panel's, drawn inside a window that stays put (see windowHeight).
    property int surfaceWidth: 0
    property int surfaceHeight: 0

    readonly property bool measured: root.surfaceWidth > 0 && root.surfaceHeight > 0

    // The window is as tall as the screen while it is up, with the panel drawn at surfaceHeight inside it and only the panel taking input. A window that followed its content was resized on every frame a section inside it opened or closed, each one a configure round trip and a new buffer: Application volume opening ran at a third of the frame rate with frames of 100 ms, against a steady 16 ms in a window that stayed put. Nothing is drawn or blurred in the rest: the popup namespaces ignore alpha under 0.1.
    readonly property int windowHeight: root.screen ? root.screen.height : 1080

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
        root.sliding = true;
        root.expanded = true;
        landing.restart();
    }

    // Rounded up, so the box is never a fraction of a pixel shorter than the text in it, and refused while the panel is moving: it finishes the slide at the size it started.
    function adoptSize(): void {
        if (root.sliding)
            return;
        root.surfaceWidth = Math.ceil(contentHolder.implicitWidth);
        root.surfaceHeight = Math.ceil(contentHolder.implicitHeight);
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

    implicitWidth: root.surfaceWidth + root.cornerSize * 2
    implicitHeight: root.measured ? root.windowHeight : 0

    mask: Region {
        item: surface
    }

    visible: root.rendered && root.measured

    // A panel is built on its first open, so its width only settles as it comes up; each of these lands before the surface is on screen.
    onImplicitWidthChanged: root.reposition()
    onScreenChanged: root.reposition()
    onShownChanged: {
        root.reposition();

        if (root.shown) {
            // Reopened before the slide out finished, so the teardown that would have thawed the size is not going to run.
            root.sliding = false;
            root.adoptSize();
            return;
        }

        landing.stop();
        root.expanded = false;
        root.settled = false;
        root.sliding = root.rendered;
    }

    // Content sized during its own construction never emits the change the connection below listens for.
    Component.onCompleted: root.adoptSize()

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

        // The surface follows the content while the panel is standing still, and ignores it while it is moving.
        Connections {
            target: contentHolder

            function onImplicitWidthChanged(): void {
                root.adoptSize();
            }

            function onImplicitHeightChanged(): void {
                root.adoptSize();
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

        // A pointer only crossing the button is not one on its way to clicking it.
        Timer {
            interval: 140
            running: root.warm && !root.prepared
            onTriggered: root.prepared = true
        },

        // And built for a moment after it leaves, so coming back does not rebuild the tree.
        Timer {
            interval: 5000
            running: root.prepared && !root.warm && !root.shown
            onTriggered: root.prepared = false
        },

        FrameAnimation {
            id: entrance

            property int steadyFrames: 0
            property real lastWidth: NaN
            property real lastHeight: NaN
            property real lastSurfaceWidth: NaN
            property real lastSurfaceHeight: NaN

            running: root.shown && root.visible && !root.expanded

            onRunningChanged: entrance.forget()

            function forget(): void {
                entrance.steadyFrames = 0;
                entrance.lastWidth = NaN;
                entrance.lastHeight = NaN;
                entrance.lastSurfaceWidth = NaN;
                entrance.lastSurfaceHeight = NaN;
            }

            onTriggered: {
                // Nothing moves until both the content and the surface the compositor handed back have stopped changing size: sliding while either is moving costs a configure round trip per frame, and draws the box at one size while the text in it is at another.
                if (contentHolder.implicitWidth !== entrance.lastWidth || contentHolder.implicitHeight !== entrance.lastHeight || clipper.width !== entrance.lastSurfaceWidth || clipper.height !== entrance.lastSurfaceHeight) {
                    entrance.lastWidth = contentHolder.implicitWidth;
                    entrance.lastHeight = contentHolder.implicitHeight;
                    entrance.lastSurfaceWidth = clipper.width;
                    entrance.lastSurfaceHeight = clipper.height;
                    entrance.steadyFrames = 0;
                    return;
                }

                // A window with no size yet is one whose first configure has not arrived.
                if (clipper.width <= 0 || clipper.height <= 0)
                    return;

                if (++entrance.steadyFrames >= 2)
                    root.beginEntrance();
            }
        },

        // A quarter second to settle, past which it opens anyway rather than waiting on something that will never stop moving.
        Timer {
            interval: 250
            running: entrance.running
            onTriggered: root.beginEntrance()
        },

        Timer {
            id: landing

            interval: Theme.durationBase + 20
            onTriggered: {
                root.sliding = false;
                root.settled = root.shown;
                root.adoptSize();
            }
        },

        Timer {
            interval: Theme.durationBase + 60
            running: !root.shown && root.rendered
            onTriggered: {
                root.rendered = false;
                root.animating = false;
                root.sliding = false;
                root.adoptSize();
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

                readonly property int hiddenY: -Math.max(surface.height, contentHolder.implicitHeight + surface.lift, root.surfaceHeight + surface.lift)

                x: root.cornerSize
                width: parent.width - root.cornerSize * 2
                height: root.surfaceHeight + surface.lift
                y: root.expanded ? -surface.lift : surface.hiddenY

                color: Theme.popupBackground
                radius: Theme.cardRadius

                // The box is the edge of the panel, not its backdrop: where the surface and the content inside it disagree on size, the difference is cut off rather than drawn beside the panel.
                clip: true

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
