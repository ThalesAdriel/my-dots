pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The window geometry Quickshell.Hyprland does not carry. Quickshell knows which
// toplevels exist and which workspace is focused, but not where a window sits or
// how big it is, and an overview is nothing without that. hyprctl -j is the only
// place to get it.
//
// Read only while something is looking. The overview is the only caller, it is
// open for a few seconds at a time, and a shell that shells out to hyprctl every
// couple of seconds for the rest of the session to keep a panel warm that nobody
// has open is a shell that costs more than it is worth.
Singleton {
    id: root

    property bool watching: false

    // [{ address, at: [x, y], size: [w, h], workspace: { id }, class, title, monitor, floating, fullscreen }]
    property var clients: []
    property var clientByAddress: ({})
    property var clientsByWorkspace: ({})

    // [{ id, name, x, y, width, height, scale, reserved: [l, t, r, b], transform }]
    property var monitors: []

    // Addresses come back from hyprctl and go straight into a dispatch string,
    // so they are checked for the shape of one first. Nothing untrusted reaches
    // this today; the check is here so that stays true if something ever does.
    function isAddress(address: string): bool {
        return /^0x[0-9A-Fa-f]+$/.test(address);
    }

    // Hyprland reads its config in Lua now, and the classic "workspace 3" string
    // is not what it answers to there. Quickshell reports which one is in use.
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

    // follow = false is what makes it a move rather than a move and a jump: the
    // window goes, the view stays, which is what dragging a preview onto another
    // workspace in the overview means.
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

    // Hyprland fires a burst of events for one user action: opening a window is
    // openwindow, then activewindow, then workspace. Reading on each one would
    // run hyprctl three times for a single change, so they collapse into one
    // read on the trailing edge.
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
