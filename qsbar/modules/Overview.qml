pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "root:/config"
import "root:/services"

// Every workspace at once, drawn to the shape of the output it lives on with its windows where they actually are: click to focus, middle click to close, drag onto another workspace to move. The previews are live captures rather than icons, which is the whole point, and only run while this is on screen.
Scope {
    id: scope

    readonly property int columns: 3
    readonly property int rows: 2

    // The same six the bar keeps a dot for, laid out the same way round.
    readonly property int workspaceCount: scope.columns * scope.rows

    // A row with nothing on it is a row of empty rectangles, so it is hidden unless the workspace you are standing on is in it.
    readonly property bool hideEmptyRows: true

    // How much of the space it could take it actually takes: the grid at full width crowds the screen edges, and this leaves it sitting in the middle.
    readonly property real sizeFactor: 0.66

    // The workspace a dragged window is currently over, or -1; lives here rather than per screen so a tile can light up while the pointer is inside it.
    property int dropTarget: -1
    property bool dragging: false

    // What the pointer is over, for the strip along the bottom; cleared on the way out so it does not describe a window that is no longer under it.
    property var hoveredClient: null

    function toggle(): void {
        UiState.overviewOpen = !UiState.overviewOpen;
    }

    function close(): void {
        UiState.overviewOpen = false;
    }

    onDraggingChanged: {
        if (!scope.dragging)
            scope.dropTarget = -1;
    }

    // Closing while a preview is mid drag would leave the flags set for the next time it opens.
    Connections {
        target: UiState

        function onOverviewOpenChanged(): void {
            if (!UiState.overviewOpen) {
                scope.dragging = false;
                scope.dropTarget = -1;
                scope.hoveredClient = null;
            }
        }
    }

    // hyprctl is only asked for window geometry while the overview is up.
    Binding {
        target: Hypr
        property: "watching"
        value: UiState.overviewOpen
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: root

            required property var modelData

            readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(root.modelData)
            readonly property var monitorData: root.hyprMonitor ? Hypr.monitorFor(root.hyprMonitor.name) : null

            readonly property int activeWorkspace: root.hyprMonitor && root.hyprMonitor.activeWorkspace ? root.hyprMonitor.activeWorkspace.id : 1

            // The overview only takes the keyboard while it is up, and only on the output the pointer is on: two exclusive keyboard grabs at once is one too many.
            readonly property bool focusedHere: Hyprland.focusedMonitor && root.hyprMonitor && Hyprland.focusedMonitor.id === root.hyprMonitor.id

            WlrLayershell.namespace: Theme.overviewLayerNamespace
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: UiState.overviewOpen && root.focusedHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            screen: root.modelData
            visible: UiState.overviewOpen
            color: "transparent"
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // The logical size of this output, which is what window coordinates are measured in; falls back to the screen while hyprctl has not answered, so the first frame is laid out rather than collapsed.
            readonly property real monitorWidth: root.monitorData && root.monitorData.width > 0 ? root.monitorData.width / (root.monitorData.scale || 1) : root.modelData.width
            readonly property real monitorHeight: root.monitorData && root.monitorData.height > 0 ? root.monitorData.height / (root.monitorData.scale || 1) : root.modelData.height
            readonly property real monitorX: root.monitorData ? root.monitorData.x : 0
            readonly property real monitorY: root.monitorData ? root.monitorData.y : 0

            readonly property int gap: 12

            // Which workspaces get a tile: whole rows drop out together, so the grid keeps its shape instead of reflowing into a ragged block.
            readonly property var visibleWorkspaces: {
                const all = [];
                for (let id = 1; id <= scope.workspaceCount; id++)
                    all.push(id);

                if (!scope.hideEmptyRows)
                    return all;

                const kept = [];
                for (let row = 0; row < scope.rows; row++) {
                    const ids = all.slice(row * scope.columns, (row + 1) * scope.columns);
                    const worth = ids.some(id => id === root.activeWorkspace || Hypr.clientsOn(id).length > 0);
                    if (worth)
                        kept.push(...ids);
                }

                // Never everything hidden: an overview with no tiles tells you nothing and gives you nowhere to click.
                return kept.length > 0 ? kept : all.slice(0, scope.columns);
            }

            readonly property int visibleRows: Math.max(Math.ceil(root.visibleWorkspaces.length / scope.columns), 1)

            // Sized so the whole grid fits either way round, then taken in a bit so it does not run to the screen edges.
            readonly property real tileWidth: {
                const byWidth = (width * scope.sizeFactor - root.gap * (scope.columns - 1)) / scope.columns;
                const byHeight = ((height * scope.sizeFactor - root.gap * (root.visibleRows - 1)) / root.visibleRows) * (root.monitorWidth / Math.max(root.monitorHeight, 1));
                return Math.floor(Math.max(Math.min(byWidth, byHeight), 80));
            }

            readonly property real tileHeight: Math.floor(root.tileWidth * (root.monitorHeight / Math.max(root.monitorWidth, 1)))

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: UiState.overviewOpen ? 0.55 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durationBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                }
            }

            // Anywhere that is not a tile closes it.
            MouseArea {
                anchors.fill: parent
                onClicked: scope.close()
            }

            // Focus grab rather than only the click catcher above: a keybind that opens something else, or a window taking focus on its own, should put the overview away too.
            HyprlandFocusGrab {
                windows: [root]
                active: UiState.overviewOpen && root.focusedHere
                onCleared: scope.close()
            }

            Item {
                anchors.fill: parent
                focus: UiState.overviewOpen && root.focusedHere

                // Arrows and hjkl walk the grid wrapping at the edges, the number row jumps straight to one; walking moves focus without closing, so you can look around before committing, and Enter and Escape are what close it.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        scope.close();
                        event.accepted = true;
                        return;
                    }

                    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        const target = event.key - Qt.Key_0;
                        if (target <= scope.workspaceCount) {
                            Hypr.focusWorkspace(target);
                            event.accepted = true;
                        }
                        return;
                    }

                    const index = Math.max(root.activeWorkspace - 1, 0);
                    let column = index % scope.columns;
                    let row = Math.floor(index / scope.columns) % scope.rows;

                    if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
                        column = (column - 1 + scope.columns) % scope.columns;
                    else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
                        column = (column + 1) % scope.columns;
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
                        row = (row - 1 + scope.rows) % scope.rows;
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
                        row = (row + 1) % scope.rows;
                    else
                        return;

                    Hypr.focusWorkspace(row * scope.columns + column + 1);
                    event.accepted = true;
                }

                Grid {
                    id: grid

                    anchors.centerIn: parent

                    columns: scope.columns
                    rowSpacing: root.gap
                    columnSpacing: root.gap

                    opacity: UiState.overviewOpen ? 1 : 0
                    scale: UiState.overviewOpen ? 1 : 0.96

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durationBase
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easingCurve
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durationBase
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easingCurve
                        }
                    }

                    Repeater {
                        // Diffed rather than handed over as a fresh array: the list is rebuilt whenever Hypr replaces its client map, which is every window event while the overview is open, and a raw array would tear down every tile and restart every capture underneath it.
                        model: ScriptModel {
                            values: root.visibleWorkspaces
                        }

                        delegate: Rectangle {
                            id: tile

                            required property var modelData

                            readonly property int workspaceId: tile.modelData
                            readonly property bool active: root.activeWorkspace === tile.workspaceId
                            readonly property bool targeted: scope.dragging && scope.dropTarget === tile.workspaceId

                            // Windows on this workspace, matched back to the live toplevel that can be captured: Quickshell knows the surface, hyprctl knows where it is, and the address ties the two together.
                            readonly property var entries: {
                                if (!UiState.overviewOpen || !ToplevelManager.toplevels)
                                    return [];

                                return ToplevelManager.toplevels.values.filter(toplevel => {
                                    if (!toplevel || !toplevel.HyprlandToplevel)
                                        return false;
                                    const client = Hypr.clientByAddress["0x" + toplevel.HyprlandToplevel.address];
                                    return client && client.workspace && client.workspace.id === tile.workspaceId;
                                });
                            }

                            width: root.tileWidth
                            height: root.tileHeight
                            radius: Theme.cardRadius

                            // Clipping is what keeps a window inside its own workspace, and exactly what has to stop while one is being dragged out of it; the tile being dragged from is lifted over its neighbours for the same reason.
                            clip: !scope.dragging
                            z: scope.dragging ? 1 : 0

                            color: Theme.overviewCard
                            border.width: tile.targeted || tile.active ? 2 : Theme.panelBorderWidth
                            border.color: tile.targeted ? Theme.accent : tile.active ? Theme.accent : Theme.cardBorder

                            // Never below 1: the tiles carry the previews, and a tile at 96% is one the desktop shows through, so the drop target reads as the accent border instead.
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.durationFast
                                }
                            }

                            // Under the windows, so a click that misses one is a click on the workspace itself.
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    Hypr.focusWorkspace(tile.workspaceId);
                                    scope.close();
                                }
                            }

                            // Lights the tile up while a dragged window is over it, and is what the drop is resolved against.
                            DropArea {
                                anchors.fill: parent
                                onEntered: scope.dropTarget = tile.workspaceId
                                onExited: {
                                    if (scope.dropTarget === tile.workspaceId)
                                        scope.dropTarget = -1;
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: tile.entries.length === 0
                                textFormat: Text.PlainText
                                text: tile.workspaceId
                                color: Theme.textMuted
                                font.family: Theme.sansFamily
                                font.pixelSize: Math.max(Math.round(root.tileHeight / 4), 12)
                                font.weight: Theme.fontWeightStrong
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 6
                                visible: tile.entries.length > 0
                                textFormat: Text.PlainText
                                text: tile.workspaceId
                                color: Theme.textMuted
                                font.family: Theme.sansFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightStrong
                            }

                            Repeater {
                                model: ScriptModel {
                                    values: tile.entries
                                }

                                delegate: Item {
                                    id: preview

                                    required property var modelData

                                    readonly property var client: Hypr.clientByAddress["0x" + preview.modelData.HyprlandToplevel.address]
                                    readonly property string address: preview.client ? preview.client.address : ""

                                    // The tile is the output shrunk by this much, so a window shrinks by the same and lands in the same relative spot.
                                    readonly property real factor: root.tileWidth / Math.max(root.monitorWidth, 1)

                                    readonly property real homeX: preview.client ? (preview.client.at[0] - root.monitorX) * preview.factor : 0
                                    readonly property real homeY: preview.client ? (preview.client.at[1] - root.monitorY) * preview.factor : 0

                                    x: preview.homeX
                                    y: preview.homeY
                                    width: preview.client ? Math.max(preview.client.size[0] * preview.factor, 10) : 0
                                    height: preview.client ? Math.max(preview.client.size[1] * preview.factor, 10) : 0

                                    visible: preview.client !== undefined && preview.client !== null

                                    // Follows the pointer while dragged, back to where the window really is when let go.
                                    Drag.active: dragArea.drag.active
                                    Drag.hotSpot.x: preview.width / 2
                                    Drag.hotSpot.y: preview.height / 2

                                    readonly property bool dragActive: dragArea.drag.active

                                    z: preview.dragActive ? 10 : 0

                                    // Pressing is not dragging: flipping the flag on press would unclip every tile on a plain click, which flickers.
                                    onDragActiveChanged: {
                                        if (preview.dragActive)
                                            scope.dragging = true;
                                    }

                                    Behavior on x {
                                        enabled: !dragArea.drag.active
                                        NumberAnimation {
                                            duration: Theme.durationFast
                                        }
                                    }

                                    Behavior on y {
                                        enabled: !dragArea.drag.active
                                        NumberAnimation {
                                            duration: Theme.durationFast
                                        }
                                    }

                                    // What the window calls itself, resolved to a desktop entry so there is something to draw while the capture is not ready; the icon arrives as an image:// handle and the plate below wants the name inside it.
                                    readonly property var entry: preview.client ? DesktopEntries.heuristicLookup(preview.client["class"]) : null

                                    readonly property string iconPath: {
                                        const raw = preview.entry && preview.entry.icon ? String(preview.entry.icon).trim() : "";
                                        const name = raw.replace(/^image:\/\/icon\//, "").split("?")[0].trim();
                                        return Quickshell.iconPath(name !== "" ? name : "application-x-executable", true);
                                    }

                                    // Opaque, and dark: this is what the capture is composited onto, and what shows in the letterbox bars beside it.
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radius
                                        color: Theme.overviewBackground
                                    }

                                    // A capture is not ready the moment it is asked for, and a view drawn before it has a frame is a blank rectangle; the icon holds the place until there is something to show, and stays for good on a window the compositor will not hand over.
                                    Image {
                                        anchors.centerIn: parent
                                        visible: !capture.hasContent && preview.iconPath !== ""

                                        source: preview.iconPath
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true

                                        width: Math.min(parent.width, parent.height) * 0.45
                                        height: width
                                        sourceSize.width: 64
                                        sourceSize.height: 64
                                    }

                                    ScreencopyView {
                                        id: capture

                                        anchors.centerIn: parent

                                        // Letterboxed rather than stretched: the tile is the shape of the output, and a window is rarely the same shape as it.
                                        readonly property real sourceAspect: {
                                            if (!preview.client)
                                                return 1;
                                            const w = preview.client.size[0];
                                            const h = preview.client.size[1];
                                            return w > 0 && h > 0 ? w / h : 1;
                                        }

                                        width: Math.min(parent.width, parent.height * capture.sourceAspect)
                                        height: Math.min(parent.height, parent.width / capture.sourceAspect)

                                        captureSource: UiState.overviewOpen && Settings.overviewPreviews ? preview.modelData : null
                                        visible: capture.hasContent

                                        // One frame, not a stream: a live capture asks the compositor forever, and a window on a workspace nobody is looking at is not being drawn, so the first frame comes back real and every one after it empty — the preview going white a moment after it appeared. A snapshot keeps the good one.
                                        live: false

                                        onCaptureSourceChanged: {
                                            if (capture.captureSource)
                                                Qt.callLater(capture.captureFrame);
                                        }

                                        Component.onCompleted: {
                                            if (capture.captureSource)
                                                capture.captureFrame();
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radius
                                        color: dragArea.containsPress ? Theme.fillPressed : dragArea.containsMouse ? Theme.fillHover : "transparent"
                                        border.width: dragArea.containsMouse || dragArea.drag.active ? 1 : 0
                                        border.color: Theme.accent
                                    }

                                    MouseArea {
                                        id: dragArea

                                        anchors.fill: parent
                                        drag.target: preview
                                        drag.threshold: 6
                                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        // The hover strip along the bottom reads this rather than the preview drawing its own label, which at this size would be smaller than it is readable.
                                        onEntered: scope.hoveredClient = preview.client
                                        onExited: {
                                            if (scope.hoveredClient === preview.client)
                                                scope.hoveredClient = null;
                                        }

                                        // clicked() still arrives after a drag, so the release records what happened and the click reads it rather than focusing a window that was only being moved.
                                        property bool wasDragged: false

                                        onReleased: {
                                            const wasDragging = dragArea.drag.active;
                                            const target = scope.dropTarget;

                                            dragArea.wasDragged = wasDragging;
                                            scope.dragging = false;

                                            // Snapping back has to be a binding again: dragging wrote over x and y directly and broke the ones that put the preview where the window is.
                                            preview.x = Qt.binding(() => preview.homeX);
                                            preview.y = Qt.binding(() => preview.homeY);

                                            if (!wasDragging || preview.address === "")
                                                return;

                                            if (target !== -1 && target !== tile.workspaceId)
                                                Hypr.moveWindowToWorkspace(preview.address, target);
                                        }

                                        onClicked: event => {
                                            if (dragArea.wasDragged) {
                                                dragArea.wasDragged = false;
                                                return;
                                            }

                                            if (preview.address === "")
                                                return;

                                            if (event.button === Qt.MiddleButton) {
                                                Hypr.closeWindow(preview.address);
                                                return;
                                            }

                                            Hypr.focusWindow(preview.address);
                                            scope.close();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // What the pointer is on, written where there is room to write it; both halves come from the application, so both are drawn as the plain text they are rather than as possible markup.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: grid.bottom
                    anchors.topMargin: 18

                    width: Math.min(hoverLabel.implicitWidth + 24, root.width - 80)
                    height: hoverLabel.implicitHeight + 14
                    radius: Theme.pill(height)

                    color: Theme.overviewCard
                    border.width: Theme.panelBorderWidth
                    border.color: Theme.cardBorder

                    opacity: scope.hoveredClient ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durationFast
                        }
                    }

                    Text {
                        id: hoverLabel

                        anchors.centerIn: parent
                        width: parent.width - 24

                        textFormat: Text.PlainText
                        text: {
                            const client = scope.hoveredClient;
                            if (!client)
                                return "";

                            const name = client["class"] ? client["class"] : "";
                            const title = client.title ? client.title : "";
                            if (name !== "" && title !== "")
                                return name + "  ·  " + title;
                            return name !== "" ? name : title;
                        }
                        color: Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    // What the Hyprland keybind talks to: qs ipc call overview toggle.
    IpcHandler {
        target: "overview"

        function toggle(): void {
            scope.toggle();
        }

        function open(): void {
            UiState.overviewOpen = true;
        }

        function close(): void {
            scope.close();
        }
    }
}
