pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The window geometry Quickshell.Hyprland does not carry, out of hyprctl -j, and read only while the overview is looking: keeping a panel nobody has open warm would cost more than it is worth.
Singleton {
    id: root

    property bool watching: false

    // [{ address, at: [x, y], size: [w, h], workspace: { id }, class, title, monitor, floating, fullscreen }]
    property var clients: []
    property var clientByAddress: ({})
    property var clientsByWorkspace: ({})

    // [{ id, name, x, y, width, height, scale, reserved: [l, t, r, b], transform }]
    property var monitors: []

    // Addresses come back from hyprctl and go straight into a dispatch string, so they are checked for the shape of one first; nothing untrusted reaches this today, and the check keeps it that way.
    function isAddress(address: string): bool {
        return /^0x[0-9A-Fa-f]+$/.test(address);
    }

    // Hyprland reads its config in Lua now, where the classic "workspace 3" string is not what it answers to; Quickshell reports which one is in use.
    function dispatch(lua: string, classic: string): void {
        Hyprland.dispatch(Hyprland.usingLua ? lua : classic);
    }

    function focusWorkspace(id: int): void {
        root.dispatch(`hl.dsp.focus({ workspace = '${id}' })`, "workspace " + id);
    }

    function focusWindow(address: string): void {
        if (!root.isAddress(address))
            return;

        root.dispatch(`hl.dsp.focus({ window = 'address:${address}' })`, "focuswindow address:" + address);
    }

    function closeWindow(address: string): void {
        if (!root.isAddress(address))
            return;

        root.dispatch(`hl.dsp.window.close('address:${address}')`, "closewindow address:" + address);
    }

    // follow = false makes it a move rather than a move and a jump: the window goes, the view stays, which is what dragging a preview onto another workspace means.
    function moveWindowToWorkspace(address: string, id: int): void {
        if (!root.isAddress(address))
            return;

        root.dispatch(`hl.dsp.window.move({ workspace = '${id}', follow = false, window = 'address:${address}' })`, `movetoworkspacesilent ${id}, address:${address}`);
    }

    function clientsOn(workspaceId: int): var {
        const list = root.clientsByWorkspace[workspaceId];
        return list !== undefined ? list : [];
    }

    function monitorFor(name: string): var {
        for (const monitor of root.monitors) {
            if (monitor.name === name)
                return monitor;
        }
        return null;
    }

    function refresh(): void {
        if (!root.watching)
            return;

        if (!clientsProcess.running)
            clientsProcess.running = true;
        if (!monitorsProcess.running)
            monitorsProcess.running = true;
    }

    onWatchingChanged: {
        if (root.watching)
            root.refresh();
    }

    // Hyprland fires a burst of events for one action (openwindow, then activewindow, then workspace), so they collapse into one read on the trailing edge rather than three hyprctl runs.
    Connections {
        target: Hyprland

        function onRawEvent(event: var): void {
            if (root.watching)
                settleTimer.restart();
        }
    }

    Timer {
        id: settleTimer

        interval: 120
        onTriggered: root.refresh()
    }

    Process {
        id: clientsProcess

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed = [];
                try {
                    parsed = JSON.parse(this.text);
                } catch (error) {
                    console.warn("pesqBar: could not read the window list from hyprctl:", error);
                    return;
                }

                if (!Array.isArray(parsed))
                    return;

                const table = {};
                const byWorkspace = {};

                for (const client of parsed) {
                    if (!client || !client.address)
                        continue;

                    table[client.address] = client;

                    const workspaceId = client.workspace ? client.workspace.id : undefined;
                    if (workspaceId === undefined)
                        continue;

                    if (byWorkspace[workspaceId] === undefined)
                        byWorkspace[workspaceId] = [];
                    byWorkspace[workspaceId].push(client);
                }

                root.clients = parsed;
                root.clientByAddress = table;
                root.clientsByWorkspace = byWorkspace;
            }
        }
    }

    Process {
        id: monitorsProcess

        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    if (Array.isArray(parsed))
                        root.monitors = parsed;
                } catch (error) {
                    console.warn("pesqBar: could not read the monitor list from hyprctl:", error);
                }
            }
        }
    }
}
