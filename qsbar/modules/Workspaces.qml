pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "root:/config"

Item {
    id: root

    readonly property var persistentIds: [1, 2, 3, 4, 5, 6]
    readonly property int itemWidth: Theme.glyphSize + 7
    readonly property int itemSpacing: Settings.workspaceSpacing

    // State first, and keyed by id: everything the row draws is looked up out of here, which is a binding re-evaluating rather than a delegate being built.
    readonly property var workspaceState: {
        const table = {};
        for (const id of root.persistentIds)
            table[id] = {
                id: id,
                occupied: false,
                urgent: false
            };

        const live = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (const workspace of live) {
            if (!workspace || workspace.id < 1)
                continue;
            table[workspace.id] = {
                id: workspace.id,
                occupied: true,
                urgent: workspace.urgent === true
            };
        }

        return table;
    }

    // The model, and only the model: a fresh array handed to a Repeater rebuilds every delegate, and Hyprland sends an event for every focus change and window open or close, so this is only replaced when the set of workspaces really moved.
    property var workspaceIds: root.persistentIds

    onWorkspaceStateChanged: {
        const ids = Object.keys(root.workspaceState).map(key => parseInt(key, 10)).sort((left, right) => left - right);

        if (ids.length !== root.workspaceIds.length || ids.some((id, index) => id !== root.workspaceIds[index]))
            root.workspaceIds = ids;
    }

    function focusWorkspace(target: string): void {
        // Pasted into a Lua expression that Hyprland evaluates, so a target that is not a workspace id or a relative step has no business going in; nothing reaches this from outside the shell today, and the check keeps it that way.
        if (!/^(?:\d+|r[-+]\d+)$/.test(target)) {
            console.warn("pesqBar: refused a workspace target that is not an id or a step:", target);
            return;
        }

        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = '${target}' })` : "workspace " + target);
    }

    readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    readonly property int focusedIndex: root.workspaceIds.indexOf(root.focusedId)

    implicitWidth: workspaceRow.implicitWidth + Theme.groupMargin * 2
    implicitHeight: Theme.barHeight

    Rectangle {
        id: indicator

        width: root.itemWidth
        height: 2
        color: Theme.textPrimary

        x: workspaceRow.x + root.focusedIndex * (root.itemWidth + root.itemSpacing)
        y: workspaceRow.y + workspaceRow.height - 2

        opacity: root.focusedIndex >= 0 ? 1 : 0

        Behavior on x {
            NumberAnimation {
                duration: Theme.durationBase
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easingCurve
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationFast
            }
        }
    }

    Row {
        id: workspaceRow

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupMargin
        spacing: root.itemSpacing

        Repeater {
            model: root.workspaceIds

            delegate: Item {
                id: workspaceItem

                required property int modelData

                readonly property var entry: root.workspaceState[workspaceItem.modelData]
                readonly property bool focused: workspaceItem.modelData === root.focusedId
                readonly property bool occupied: workspaceItem.entry !== undefined && workspaceItem.entry.occupied
                readonly property bool urgent: workspaceItem.entry !== undefined && workspaceItem.entry.urgent

                width: root.itemWidth
                height: Theme.barHeight - 8

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.hoverRadius
                    color: workspaceMouse.containsPress ? Theme.fillPressed : workspaceMouse.containsMouse ? Theme.fillHover : "transparent"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -1

                    text: Glyphs.workspaceLabel(workspaceItem.modelData)
                    font.family: Theme.glyphFamily
                    font.pixelSize: Theme.glyphSize

                    color: {
                        if (workspaceItem.urgent)
                            return Theme.urgent;
                        if (workspaceItem.focused)
                            return Theme.textPrimary;
                        if (workspaceItem.occupied)
                            return Theme.textSecondary;
                        return Theme.textMuted;
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durationBase
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easingCurve
                        }
                    }
                }

                MouseArea {
                    id: workspaceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.focusWorkspace(String(workspaceItem.modelData))
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: false
        onWheel: event => {
            const steps = event.angleDelta.y;
            if (steps === 0)
                return;
            root.focusWorkspace(steps > 0 ? "r-1" : "r+1");
        }
    }
}
