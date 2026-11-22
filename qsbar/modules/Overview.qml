pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "root:/config"
import "root:/components"
import "root:/services"

// Every workspace at once, drawn to the shape of the output it lives on with its windows where they actually are.
Scope {
    id: scope

    readonly property int columns: 3
    readonly property int rows: 2

    // The same six the bar keeps a dot for, laid out the same way round.
    readonly property int workspaceCount: scope.columns * scope.rows

    // How much of the space it could take it actually takes.
    readonly property real sizeFactor: 0.72

    // Drag state shared across monitors/tiles.
    property int dropTarget: -1
    property int draggingFromWorkspace: -1
    property bool dragging: false

    // What the pointer is over, for the pill along the bottom.
    property var hoveredClient: null

    // Pre-grouped map of workspaceId -> [toplevel, ...], computed once per update instead of O(W*N) per tile.
    readonly property var toplevelsByWorkspace: {
        if (!UiState.overviewOpen || !ToplevelManager.toplevels)
            return ({});

        const grouped = {};
        const values = ToplevelManager.toplevels.values;
        for (let i = 0; i < values.length; i++) {
            const tl = values[i];
            if (!tl || !tl.HyprlandToplevel)
                continue;
            const client = Hypr.clientByAddress["0x" + tl.HyprlandToplevel.address];
            if (!client || !client.workspace)
                continue;
            const wsId = client.workspace.id;
            if (grouped[wsId] === undefined)
                grouped[wsId] = [];
            grouped[wsId].push(tl);
        }
        return grouped;
    }

    function entriesFor(workspaceId: int): var {
        const list = scope.toplevelsByWorkspace[workspaceId];
        return list !== undefined ? list : [];
    }

    function monitorById(id: int): var {
        for (let i = 0; i < Hypr.monitors.length; i++) {
            if (Hypr.monitors[i].id === id)
                return Hypr.monitors[i];
        }
        return null;
    }

    function toggle(): void {
        UiState.overviewOpen = !UiState.overviewOpen;
    }

    function close(): void {
        UiState.overviewOpen = false;
    }

    onDraggingChanged: {
        if (!scope.dragging) {
            scope.dropTarget = -1;
            scope.draggingFromWorkspace = -1;
        }
    }

    // Closing while a preview is mid drag would leave the flags set for the next time it opens.
    Connections {
        target: UiState

        function onOverviewOpenChanged(): void {
            if (!UiState.overviewOpen) {
                scope.dragging = false;
                scope.dropTarget = -1;
                scope.draggingFromWorkspace = -1;
                scope.hoveredClient = null;
                Qt.callLater(gc);
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
        id: overviewVariants

        model: Quickshell.screens

        PanelWindow {
            id: root

            required property var modelData

            readonly property HyprlandMonitor hyprMonitor: Hyprland.monitorFor(root.modelData)
            readonly property var monitorData: root.hyprMonitor ? Hypr.monitorFor(root.hyprMonitor.name) : null

            readonly property int activeWorkspace: root.hyprMonitor && root.hyprMonitor.activeWorkspace ? root.hyprMonitor.activeWorkspace.id : 1

            // The overview only takes the keyboard while it is up, and only on the output the pointer is on.
            readonly property bool focusedHere: Hyprland.focusedMonitor && root.hyprMonitor && Hyprland.focusedMonitor.id === root.hyprMonitor.id

            WlrLayershell.namespace: "qsbar"
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

            // Logical size of this output (accounting for transform rotation & scale).
            readonly property bool rotated: root.monitorData && (root.monitorData.transform === 1 || root.monitorData.transform === 3)
            readonly property real rawW: root.monitorData && root.monitorData.width > 0 ? root.monitorData.width / (root.monitorData.scale || 1) : root.modelData.width
            readonly property real rawH: root.monitorData && root.monitorData.height > 0 ? root.monitorData.height / (root.monitorData.scale || 1) : root.modelData.height
            readonly property real monitorWidth: root.rotated ? root.rawH : root.rawW
            readonly property real monitorHeight: root.rotated ? root.rawW : root.rawH
            readonly property real monitorX: root.monitorData ? root.monitorData.x : 0
            readonly property real monitorY: root.monitorData ? root.monitorData.y : 0

            readonly property int gap: 14

            // Which workspaces get a tile: a row with nothing on it would be a row of empty rectangles.
            readonly property var visibleWorkspaces: {
                if (!UiState.overviewOpen)
                    return [];

                const all = [];
                for (let id = 1; id <= scope.workspaceCount; id++)
                    all.push(id);

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

            // Sized so the whole grid fits either way round, with comfortable room for the hover pill below.
            readonly property real tileWidth: {
                const byWidth = (width * scope.sizeFactor - root.gap * (scope.columns - 1)) / scope.columns;
                const byHeight = ((height * scope.sizeFactor - root.gap * (root.visibleRows - 1)) / root.visibleRows) * (root.monitorWidth / Math.max(root.monitorHeight, 1));
                return Math.floor(Math.max(Math.min(byWidth, byHeight), 100));
            }

            readonly property real tileHeight: Math.floor(root.tileWidth * (root.monitorHeight / Math.max(root.monitorWidth, 1)))

            // Zero ScreencopyViews or preview trees kept in RAM while Overview is closed.
            Loader {
                anchors.fill: parent
                active: UiState.overviewOpen

                sourceComponent: Item {
                    anchors.fill: parent
                    focus: UiState.overviewOpen && root.focusedHere

                    Component.onCompleted: {
                        if (root.focusedHere)
                            forceActiveFocus();
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "#000000"
                        opacity: UiState.overviewOpen ? 0.62 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durationFast
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

                    // Arrows and hjkl walk only visible workspaces, number keys jump straight to one.
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

                        const list = root.visibleWorkspaces;
                        if (list.length === 0)
                            return;
                        const pos = Math.max(list.indexOf(root.activeWorkspace), 0);
                        let nextPos = pos;

                        if (event.key === Qt.Key_Left || event.key === Qt.Key_H)
                            nextPos = (pos - 1 + list.length) % list.length;
                        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L)
                            nextPos = (pos + 1) % list.length;
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
                            nextPos = (pos - scope.columns + list.length) % list.length;
                        else if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
                            nextPos = (pos + scope.columns) % list.length;
                        else
                            return;

                        Hypr.focusWorkspace(list[nextPos]);
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
                                duration: Theme.durationFast
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
                            model: ScriptModel {
                                values: root.visibleWorkspaces
                            }

                            delegate: Rectangle {
                                id: tile

                                required property var modelData

                                readonly property int workspaceId: tile.modelData
                                readonly property bool active: root.activeWorkspace === tile.workspaceId
                                readonly property bool targeted: scope.dragging && scope.dropTarget === tile.workspaceId
                                readonly property bool dragSource: scope.dragging && scope.draggingFromWorkspace === tile.workspaceId
                                readonly property var entries: scope.entriesFor(tile.workspaceId)

                                width: root.tileWidth
                                height: root.tileHeight
                                radius: Math.max(Theme.cardRadius, 6)

                                // Only the tile currently being dragged FROM unclips and raises above every other tile.
                                clip: !tile.dragSource
                                z: tile.dragSource ? 20 : (tile.targeted ? 5 : 0)

                                color: tile.targeted ? Qt.tint(Theme.solidCard, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)) : (tileMouse.containsMouse ? Qt.tint(Theme.solidCard, Qt.rgba(1, 1, 1, 0.04)) : Theme.solidCard)
                                border.width: tile.targeted || tile.active ? 2 : 1
                                border.color: tile.targeted || tile.active ? Theme.accent : (tileMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.24) : Theme.cardBorder)

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Theme.durationFast
                                    }
                                }

                                // Under the windows, so a click that misses one is a click on the workspace itself.
                                MouseArea {
                                    id: tileMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
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

                                // Empty workspace center numeral
                                Text {
                                    anchors.centerIn: parent
                                    visible: tile.entries.length === 0
                                    textFormat: Text.PlainText
                                    text: tile.workspaceId
                                    color: tile.active ? Theme.accent : Theme.textMuted
                                    opacity: tile.active ? 0.55 : 0.45
                                    font.family: Theme.sansFamily
                                    font.pixelSize: Math.max(Math.round(root.tileHeight / 3.8), 16)
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

                                        // Use the client's actual monitor geometry so windows from a 2nd monitor map cleanly inside the tile.
                                        readonly property var clientMon: preview.client && preview.client.monitor !== undefined ? scope.monitorById(preview.client.monitor) : null
                                        readonly property bool clientRotated: preview.clientMon && (preview.clientMon.transform === 1 || preview.clientMon.transform === 3)
                                        readonly property real srcMonW: {
                                            if (preview.clientMon && preview.clientMon.width > 0) {
                                                const s = preview.clientMon.scale || 1;
                                                return (preview.clientRotated ? preview.clientMon.height : preview.clientMon.width) / s;
                                            }
                                            return root.monitorWidth;
                                        }
                                        readonly property real srcMonH: {
                                            if (preview.clientMon && preview.clientMon.height > 0) {
                                                const s = preview.clientMon.scale || 1;
                                                return (preview.clientRotated ? preview.clientMon.width : preview.clientMon.height) / s;
                                            }
                                            return root.monitorHeight;
                                        }
                                        readonly property real srcMonX: preview.clientMon ? preview.clientMon.x : root.monitorX
                                        readonly property real srcMonY: preview.clientMon ? preview.clientMon.y : root.monitorY

                                        readonly property real scaleX: root.tileWidth / Math.max(preview.srcMonW, 1)
                                        readonly property real scaleY: root.tileHeight / Math.max(preview.srcMonH, 1)
                                        readonly property real factor: Math.min(preview.scaleX, preview.scaleY)

                                        readonly property real pad: 3
                                        readonly property real rawW: preview.client ? Math.max(preview.client.size[0] * preview.factor - preview.pad * 2, 16) : 0
                                        readonly property real rawH: preview.client ? Math.max(preview.client.size[1] * preview.factor - preview.pad * 2, 16) : 0
                                        readonly property real homeX: preview.client ? Math.min(Math.max((preview.client.at[0] - preview.srcMonX) * preview.factor + preview.pad, preview.pad), Math.max(root.tileWidth - preview.rawW - preview.pad, preview.pad)) : 0
                                        readonly property real homeY: preview.client ? Math.min(Math.max((preview.client.at[1] - preview.srcMonY) * preview.factor + preview.pad, preview.pad), Math.max(root.tileHeight - preview.rawH - preview.pad, preview.pad)) : 0

                                        x: preview.homeX
                                        y: preview.homeY
                                        width: Math.min(preview.rawW, Math.max(root.tileWidth - preview.pad * 2, 16))
                                        height: Math.min(preview.rawH, Math.max(root.tileHeight - preview.pad * 2, 16))

                                        visible: preview.client !== undefined && preview.client !== null

                                        Drag.active: dragArea.drag.active
                                        Drag.hotSpot.x: preview.width / 2
                                        Drag.hotSpot.y: preview.height / 2

                                        readonly property bool dragActive: dragArea.drag.active
                                        readonly property bool hovered: dragArea.containsMouse || closeMouse.containsMouse

                                        z: preview.dragActive ? 30 : (preview.hovered ? 5 : 1)

                                        onDragActiveChanged: {
                                            if (preview.dragActive) {
                                                scope.draggingFromWorkspace = tile.workspaceId;
                                                scope.dragging = true;
                                            }
                                        }

                                        Behavior on x {
                                            enabled: !dragArea.drag.active
                                            NumberAnimation {
                                                duration: Theme.durationFast
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Behavior on y {
                                            enabled: !dragArea.drag.active
                                            NumberAnimation {
                                                duration: Theme.durationFast
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        readonly property var entry: preview.client ? DesktopEntries.heuristicLookup(preview.client["class"]) : null

                                        readonly property string iconPath: {
                                            const raw = preview.entry && preview.entry.icon ? String(preview.entry.icon).trim() : "";
                                            const name = raw.replace(/^image:\/\/icon\//, "").split("?")[0].trim();
                                            return Quickshell.iconPath(name !== "" ? name : "application-x-executable", true);
                                        }

                                        // Window card frame
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Math.max(Theme.radius, 4)
                                            color: Theme.solidBackground
                                            border.width: preview.hovered || preview.dragActive ? 1.5 : 1
                                            border.color: preview.hovered || preview.dragActive ? Theme.accent : Theme.cardBorder
                                            clip: true

                                            // Fallback app icon while ScreencopyView is capturing or disabled.
                                            Image {
                                                anchors.centerIn: parent
                                                visible: !capture.hasContent && preview.iconPath !== ""

                                                source: preview.iconPath
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: false

                                                width: Math.min(parent.width, parent.height) * 0.42
                                                height: width
                                                sourceSize.width: 64
                                                sourceSize.height: 64
                                            }

                                            // Single one-shot capture per window, aspect-ratio preserved (no stretching).
                                            ScreencopyView {
                                                id: capture

                                                anchors.centerIn: parent

                                                readonly property real sourceAspect: {
                                                    if (!preview.client)
                                                        return 1;
                                                    const w = preview.client.size[0];
                                                    const h = preview.client.size[1];
                                                    return w > 0 && h > 0 ? w / h : 1;
                                                }

                                                width: Math.min(parent.width - 2, (parent.height - 2) * capture.sourceAspect)
                                                height: Math.min(parent.height - 2, (parent.width - 2) / capture.sourceAspect)

                                                captureSource: UiState.overviewOpen && Settings.overviewPreviews ? preview.modelData : null
                                                visible: capture.hasContent
                                                live: false

                                                onCaptureSourceChanged: {
                                                    if (capture.captureSource)
                                                        Qt.callLater(capture.captureFrame);
                                                }
                                            }

                                            // Hover tint
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                color: dragArea.containsPress ? Theme.fillPressed : (preview.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                            }

                                            // Compact bottom title strip on hover (when the window tile is wide enough)
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                height: 22
                                                visible: preview.hovered && !preview.dragActive && preview.width >= 90 && preview.height >= 54
                                                color: Qt.rgba(0, 0, 0, 0.72)

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.leftMargin: 6
                                                    anchors.rightMargin: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    textFormat: Text.PlainText
                                                    text: preview.client ? (preview.client.title || preview.client["class"] || "") : ""
                                                    color: Theme.textPrimary
                                                    font.family: Theme.sansFamily
                                                    font.pixelSize: Math.max(Theme.fontSizeSmall - 1, 10)
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: dragArea

                                            anchors.fill: parent
                                            drag.target: preview
                                            drag.threshold: 6
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            onEntered: scope.hoveredClient = preview.client
                                            onExited: {
                                                if (scope.hoveredClient === preview.client)
                                                    scope.hoveredClient = null;
                                            }

                                            property bool wasDragged: false

                                            onReleased: {
                                                const wasDragging = dragArea.drag.active;
                                                const target = scope.dropTarget;

                                                dragArea.wasDragged = wasDragging;
                                                scope.dragging = false;

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

                                        // Quick close button on hover (top-right corner of the window preview)
                                        Rectangle {
                                            id: closeBtn

                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.margins: 4

                                            width: 20
                                            height: 20
                                            radius: Theme.pill(20)
                                            visible: preview.hovered && !preview.dragActive && preview.width >= 48 && preview.height >= 40
                                            color: closeMouse.containsMouse ? Theme.urgent : Qt.rgba(0, 0, 0, 0.72)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.18)

                                            IconText {
                                                anchors.centerIn: parent
                                                fillBarHeight: false
                                                text: Glyphs.xmark
                                                color: Theme.textPrimary
                                                font.pixelSize: 9
                                            }

                                            MouseArea {
                                                id: closeMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (preview.address !== "")
                                                        Hypr.closeWindow(preview.address);
                                                }
                                            }
                                        }
                                    }
                                }

                                // Crisp workspace badge pill in the top-left corner (always above window previews)
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    z: 10

                                    height: 20
                                    width: wsBadgeRow.implicitWidth + 12
                                    radius: Theme.pill(20)
                                    color: tile.active ? Theme.accent : Qt.rgba(0, 0, 0, 0.68)
                                    border.width: tile.active ? 0 : 1
                                    border.color: Qt.rgba(1, 1, 1, 0.14)

                                    Row {
                                        id: wsBadgeRow

                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            textFormat: Text.PlainText
                                            text: tile.workspaceId
                                            color: Theme.textPrimary
                                            font.family: Theme.sansFamily
                                            font.pixelSize: Math.max(Theme.fontSizeSmall - 1, 10)
                                            font.weight: Theme.fontWeightStrong
                                        }

                                        Text {
                                            visible: tile.entries.length > 0
                                            textFormat: Text.PlainText
                                            text: "· " + tile.entries.length
                                            color: tile.active ? Qt.rgba(1, 1, 1, 0.85) : Theme.textSecondary
                                            font.family: Theme.sansFamily
                                            font.pixelSize: Math.max(Theme.fontSizeSmall - 2, 9)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Bottom status pill: shows hovered window title, or subtle shortcut hints when idle.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: grid.bottom
                        anchors.topMargin: 16

                        width: Math.min(hoverLabel.implicitWidth + 28, root.width - 80)
                        height: hoverLabel.implicitHeight + 14
                        radius: Theme.pill(height)

                        color: Theme.solidCard
                        border.width: 1
                        border.color: scope.hoveredClient ? Theme.accent : Theme.cardBorder

                        opacity: UiState.overviewOpen ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durationFast
                            }
                        }

                        Text {
                            id: hoverLabel

                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, root.width - 108)

                            textFormat: Text.PlainText
                            text: {
                                const client = scope.hoveredClient;
                                if (!client)
                                    return "Click: focus   ·   Drag: move workspace   ·   Middle-click / ×: close   ·   Esc: close";

                                const name = client["class"] ? client["class"] : "";
                                const title = client.title ? client.title : "";
                                if (name !== "" && title !== "")
                                    return name + "  ·  " + title;
                                return name !== "" ? name : title;
                            }
                            color: scope.hoveredClient ? Theme.textPrimary : Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
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
