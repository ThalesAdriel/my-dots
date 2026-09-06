pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

// The arrangement canvas and the fields for whichever display is selected on
// it, filling its own sheet off the bottom of settings. Still a narrow column,
// so the mode list opens inline rather than as a dropdown: a popup anchored
// inside a popup is two levels of xdg popup for a list the sheet can scroll.
Item {
    id: root

    readonly property int canvasHeight: 240

    // How close a pull is, measured on screen, and how far it is ever allowed to
    // reach in the arrangement itself. The canvas covers thousands of logical
    // pixels in a few hundred, so without the second number a snap would drag a
    // display from a third of a screen away.
    readonly property int snapDistance: 14
    readonly property int snapLimit: 160

    property bool modesOpen: false
    property bool dragging: false

    readonly property var selectedMonitor: {
        for (const monitor of Displays.monitors) {
            if (monitor.name === Displays.selected)
                return monitor;
        }
        return null;
    }

    readonly property var selectedEntry: Displays.entryFor(Displays.selected)

    // The rectangle every display fits inside, in logical coordinates, with a
    // little air so a display never sits flush against the canvas edge.
    readonly property var liveBounds: {
        const names = Object.keys(Displays.draft);
        if (names.length === 0)
            return {
                x: 0,
                y: 0,
                width: 1,
                height: 1
            };

        let left = Infinity;
        let top = Infinity;
        let right = -Infinity;
        let bottom = -Infinity;

        for (const name of names) {
            const entry = Displays.draft[name];
            const size = Displays.logicalSize(entry);
            left = Math.min(left, entry.x);
            top = Math.min(top, entry.y);
            right = Math.max(right, entry.x + size.width);
            bottom = Math.max(bottom, entry.y + size.height);
        }

        const padding = Math.max((right - left) * 0.06, 200);
        return {
            x: left - padding,
            y: top - padding,
            width: (right - left) + padding * 2,
            height: (bottom - top) + padding * 2
        };
    }

    // Frozen for the length of a drag. The bounds follow the arrangement, the
    // scale follows the bounds and every plate's position follows the scale, so
    // left live the whole canvas would rescale under the pointer as the display
    // being dragged pushed the edges of the arrangement around.
    property var bounds: root.liveBounds

    onDraggingChanged: {
        if (root.dragging) {
            const frozen = root.bounds;
            root.bounds = frozen;
        } else {
            root.bounds = Qt.binding(() => root.liveBounds);
        }
    }

    readonly property real canvasScale: {
        const box = root.bounds;
        if (box.width <= 0 || box.height <= 0)
            return 0.02;
        return Math.min(canvas.width / box.width, canvas.height / box.height);
    }

    // Centred rather than parked in the corner, so a single display sits in the
    // middle of the canvas the way it sits in the middle of the desk.
    readonly property real offsetX: (canvas.width - root.bounds.width * root.canvasScale) / 2
    readonly property real offsetY: (canvas.height - root.bounds.height * root.canvasScale) / 2

    function toCanvasX(logical: real): real {
        return root.offsetX + (logical - root.bounds.x) * root.canvasScale;
    }

    function toCanvasY(logical: real): real {
        return root.offsetY + (logical - root.bounds.y) * root.canvasScale;
    }

    // Edges and centres of every other display, plus the origin, are what a
    // dragged display sticks to. Everything is in logical pixels, so the pull
    // is the same however far the canvas is zoomed out.
    function snapAxis(name: string, value: real, size: real, horizontal: bool): real {
        const targets = [0];

        for (const other of Object.keys(Displays.draft)) {
            if (other === name)
                continue;

            const entry = Displays.draft[other];
            const otherSize = Displays.logicalSize(entry);
            const start = horizontal ? entry.x : entry.y;
            const extent = horizontal ? otherSize.width : otherSize.height;

            targets.push(start, start + extent, start + extent / 2);
        }

        const threshold = Math.min(root.snapDistance / Math.max(root.canvasScale, 0.0001), root.snapLimit);
        let best = value;
        let bestDistance = threshold;

        for (const target of targets) {
            // The leading edge, the trailing edge and the centre all get to
            // stick, which is what makes two displays line up along a shared
            // edge as readily as along their middles.
            for (const candidate of [target, target - size, target - size / 2]) {
                const distance = Math.abs(value - candidate);
                if (distance < bestDistance) {
                    bestDistance = distance;
                    best = candidate;
                }
            }
        }

        return Math.round(best);
    }

    function nudge(axis: string, amount: int): void {
        const entry = root.selectedEntry;
        if (!entry)
            return;

        const changes = {};
        changes[axis] = entry[axis] + amount;
        Displays.update(Displays.selected, changes);
    }

    implicitHeight: layout.implicitHeight

    component StepperRow: Item {
        id: stepperRow

        property string label: ""
        property int value: 0

        signal stepped(int amount)

        width: parent.width
        height: 30

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: stepperRow.label
            color: Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: 54
                height: 26
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: String(stepperRow.value)
                color: Theme.textPrimary
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            PanelButton {
                label: "−"
                implicitWidth: 26
                onActivated: stepperRow.stepped(-10)
            }

            PanelButton {
                label: "+"
                implicitWidth: 26
                onActivated: stepperRow.stepped(10)
            }
        }
    }

    Column {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top

        spacing: 8

        PanelMessage {
            width: parent.width
            visible: !Displays.available
            text: "hyprctl is not answering, so the layout cannot be read."
        }

        Text {
            width: parent.width
            text: "Drag a display to move it. Nearby edges and centres snap together."
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        Rectangle {
            id: canvas

            width: parent.width
            height: root.canvasHeight
            radius: Theme.radius
            color: Theme.fillTrack
            clip: true

            Repeater {
                model: Displays.monitors

                delegate: Rectangle {
                    id: plate

                    required property var modelData
                    required property int index

                    readonly property var entry: Displays.draft[plate.modelData.name]
                    readonly property bool chosen: Displays.selected === plate.modelData.name
                    readonly property var size: plate.entry ? Displays.logicalSize(plate.entry) : ({
                            width: 0,
                            height: 0
                        })

                    visible: !!plate.entry

                    x: plate.entry ? root.toCanvasX(plate.entry.x) : 0
                    y: plate.entry ? root.toCanvasY(plate.entry.y) : 0
                    width: Math.max(plate.size.width * root.canvasScale, 8)
                    height: Math.max(plate.size.height * root.canvasScale, 8)

                    radius: Theme.radius
                    color: plate.chosen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28) : Theme.skeletonFill
                    border.width: 1
                    border.color: plate.chosen ? Theme.accent : Theme.cardBorder

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 4
                        anchors.right: parent.right

                        text: (plate.index + 1) + "  " + plate.modelData.name
                        color: plate.chosen ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.monoFamily
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: plateMouse

                        property real grabX: 0
                        property real grabY: 0
                        property int startX: 0
                        property int startY: 0

                        anchors.fill: parent
                        cursorShape: Qt.SizeAllCursor

                        onPressed: event => {
                            Displays.selected = plate.modelData.name;
                            plateMouse.grabX = event.x;
                            plateMouse.grabY = event.y;
                            plateMouse.startX = plate.entry.x;
                            plateMouse.startY = plate.entry.y;
                            root.dragging = true;
                        }

                        onReleased: root.dragging = false
                        onCanceled: root.dragging = false

                        onPositionChanged: event => {
                            if (!plateMouse.pressed || !plate.entry)
                                return;

                            // Back out to logical pixels before snapping, so the
                            // pull is measured against the arrangement rather
                            // than against however big the canvas happens to be.
                            const deltaX = (event.x - plateMouse.grabX) / root.canvasScale;
                            const deltaY = (event.y - plateMouse.grabY) / root.canvasScale;

                            const name = plate.modelData.name;
                            Displays.update(name, {
                                x: root.snapAxis(name, plateMouse.startX + deltaX, plate.size.width, true),
                                y: root.snapAxis(name, plateMouse.startY + deltaY, plate.size.height, false)
                            });
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: root.selectedMonitor !== null
            text: root.selectedMonitor ? root.selectedMonitor.description : ""
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightStrong
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.selectedEntry !== null && root.selectedEntry.scale !== 1
            text: {
                if (!root.selectedEntry)
                    return "";
                const size = Displays.logicalSize(root.selectedEntry);
                return size.width + "×" + size.height + " logical · " + root.selectedEntry.scale + "× scale";
            }
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        StepperRow {
            visible: root.selectedEntry !== null
            label: "X"
            value: root.selectedEntry ? root.selectedEntry.x : 0
            onStepped: amount => root.nudge("x", amount)
        }

        StepperRow {
            visible: root.selectedEntry !== null
            label: "Y"
            value: root.selectedEntry ? root.selectedEntry.y : 0
            onStepped: amount => root.nudge("y", amount)
        }

        Item {
            width: parent.width
            height: 30
            visible: root.selectedEntry !== null

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Mode"
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: Math.min(modeLabel.implicitWidth + 34, parent.width - 50)
                height: 26
                radius: Theme.radius
                color: modeMouse.containsPress ? Theme.fillPressed : modeMouse.containsMouse ? Theme.fillHover : Theme.fillTrack

                Text {
                    id: modeLabel

                    anchors.left: parent.left
                    anchors.right: modeChevron.left
                    anchors.leftMargin: 9
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter

                    text: root.selectedEntry ? Displays.modeLabel(root.selectedEntry) : ""
                    color: Theme.textPrimary
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                IconText {
                    id: modeChevron

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    fillBarHeight: false
                    text: root.modesOpen ? Glyphs.angleDown : Glyphs.angleRight
                    color: Theme.textMuted
                    font.pixelSize: 9
                }

                MouseArea {
                    id: modeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.modesOpen = !root.modesOpen
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2
            visible: root.modesOpen && root.selectedMonitor !== null

            Repeater {
                model: root.selectedMonitor ? root.selectedMonitor.modes : []

                delegate: Rectangle {
                    id: modeRow

                    required property var modelData

                    readonly property bool chosen: root.selectedEntry && root.selectedEntry.width === modeRow.modelData.width && root.selectedEntry.height === modeRow.modelData.height && Math.abs(root.selectedEntry.refresh - modeRow.modelData.refresh) < 0.01

                    width: parent.width
                    height: 24
                    radius: Theme.radius
                    color: {
                        if (modeRowMouse.containsPress)
                            return Theme.fillPressed;
                        if (modeRowMouse.containsMouse)
                            return Theme.fillHover;
                        return modeRow.chosen ? Theme.fillTrack : "transparent";
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 9
                        anchors.verticalCenter: parent.verticalCenter

                        text: modeRow.modelData.label
                        color: modeRow.chosen ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.monoFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    MouseArea {
                        id: modeRowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Displays.update(Displays.selected, {
                                width: modeRow.modelData.width,
                                height: modeRow.modelData.height,
                                refresh: modeRow.modelData.refresh
                            });
                            root.modesOpen = false;
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: 30
            visible: root.selectedEntry !== null

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Scale"
                color: Theme.textSecondary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: Displays.scaleOptions

                    delegate: Rectangle {
                        id: scaleChoice

                        required property real modelData

                        readonly property bool chosen: root.selectedEntry && Math.abs(root.selectedEntry.scale - scaleChoice.modelData) < 0.001

                        width: scaleLabel.implicitWidth + 14
                        height: 22
                        radius: Theme.radius
                        color: {
                            if (scaleMouse.containsPress)
                                return Theme.fillPressed;
                            if (scaleMouse.containsMouse)
                                return Theme.fillHover;
                            return scaleChoice.chosen ? Theme.accent : Theme.fillTrack;
                        }

                        Text {
                            id: scaleLabel
                            anchors.centerIn: parent
                            text: scaleChoice.modelData + "×"
                            color: scaleChoice.chosen ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.monoFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: scaleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Displays.update(Displays.selected, {
                                scale: scaleChoice.modelData
                            })
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: Displays.previewing
            text: "Previewing. Putting the old layout back in " + Displays.previewSeconds + "s unless you save it."
            color: Theme.accent
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
        }

        Row {
            spacing: 6

            PanelButton {
                label: "Reset"
                available: Displays.dirty || Displays.hasSavedLayout || Displays.previewing
                onActivated: Displays.reset()
            }

            PanelButton {
                label: "Identify"
                onActivated: Displays.identify()
            }

            PanelButton {
                label: Displays.previewing ? "Stop" : "Preview"
                available: Displays.dirty || Displays.previewing
                onActivated: {
                    if (Displays.previewing)
                        Displays.cancelPreview(true);
                    else
                        Displays.preview();
                }
            }
        }

        PanelButton {
            width: parent.width
            label: "Save layout"
            accented: true
            available: Displays.dirty || Displays.previewing
            onActivated: Displays.save()
        }

        PanelMessage {
            width: parent.width
            visible: Displays.lastError !== ""
            warning: true
            text: Displays.lastError
        }
    }
}
