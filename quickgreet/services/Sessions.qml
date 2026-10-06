pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The Wayland sessions installed, read out of their desktop files.
Singleton {
    id: root

    property var list: []
    property int current: 0

    readonly property var session: root.list.length > 0 ? root.list[Math.min(root.current, root.list.length - 1)] : null
    readonly property string lastUser: memory.user

    // One write for both, and straight away: greetd ends this process right after the session launches.
    function remember(user) {
        memory.user = user;
        memory.session = root.session ? root.session.id : "";
        file.writeAdapter();
    }

    // "path:Key=Value" per line, from grep.
    function parse(text) {
        const files = {};
        for (const line of text.split("\n")) {
            const colon = line.indexOf(":");
            const equals = line.indexOf("=", colon);
            if (colon < 0 || equals < 0)
                continue;
            const path = line.slice(0, colon);
            const key = line.slice(colon + 1, equals);
            const entry = files[path] || (files[path] = {});
            if (entry[key] === undefined)
                entry[key] = line.slice(equals + 1).trim();
        }

        // The first file of an id is the one that counts, /usr/local's before /usr/share's as XDG has it, even when what it says is Hidden.
        const found = [];
        const seen = {};
        for (const path of Object.keys(files)) {
            const entry = files[path];
            const id = path.slice(path.lastIndexOf("/") + 1).replace(/\.desktop$/, "");
            if (seen[id])
                continue;
            seen[id] = true;
            if (!entry.Exec || entry.Hidden === "true" || entry.NoDisplay === "true")
                continue;

            const name = entry.Name || id;
            const desktops = (entry.DesktopNames || name).replace(/;+$/, "").replace(/;/g, ":");

            // Exec quoting is the shell's double quoting.
            found.push({
                id: id,
                name: name,
                command: ["/bin/sh", "-c", entry.Exec],
                environment: ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=" + id, "XDG_CURRENT_DESKTOP=" + desktops]
            });
        }

        found.sort((a, b) => a.name.localeCompare(b.name));
        root.list = found;
        root.current = Math.max(0, found.findIndex(entry => entry.id === memory.session));
    }

    // -s keeps quiet about a directory without sessions, whose pattern reaches grep unexpanded.
    Process {
        running: true
        command: ["sh", "-c", "grep -sH -E '^(Name|Exec|DesktopNames|Hidden|NoDisplay)=' /usr/local/share/wayland-sessions/*.desktop /usr/share/wayland-sessions/*.desktop; true"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    // Under the greeter user's state directory.
    FileView {
        id: file

        path: Quickshell.statePath("state.json")
        blockLoading: true
        printErrors: false
        blockWrites: true

        adapter: JsonAdapter {
            id: memory

            property string user: ""
            property string session: ""
        }
    }
}
