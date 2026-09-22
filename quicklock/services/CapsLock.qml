pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property var sources: []

    function read(path) {
        if (probe.path === path)
            probe.reload();
        else
            probe.path = path;
        return probe.text();
    }

    function refresh() {
        const list = root.sources;
        if (list.length === 0)
            return;

        let on = false;
        for (let i = 0; i < list.length; ++i) {
            const value = root.read(list[i]);
            if (value && parseInt(value, 10) > 0) {
                on = true;
                break;
            }
        }
        root.active = on;
    }

    function observe(event) {
        if (root.sources.length > 0) {
            // Only the key that can move it, and only after the fact: the LED is still reporting the old state inside the event that toggled it, which is what the settle is for. Reading it on every key put a blocking sysfs load in the middle of typing a password to re-read a value that had not changed, and the answer the immediate read gave was the stale one anyway.
            if (event.key === Qt.Key_CapsLock)
                settle.restart();
            return;
        }

        const t = event.text;
        if (t && t.length === 1 && /[a-zA-Z]/.test(t)) {
            const upper = t === t.toUpperCase();
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            root.active = upper !== shift;
        }
    }

    FileView {
        id: probe
        blockLoading: true
        printErrors: false
    }

    Timer {
        id: settle
        interval: 60
        onTriggered: root.refresh()
    }

    FolderListModel {
        id: leds
        folder: "file:///sys/class/leds"
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
        sortField: FolderListModel.Unsorted

        onCountChanged: {
            const found = [];
            for (let i = 0; i < count; ++i) {
                const name = get(i, "fileName");
                if (name && name.toLowerCase().indexOf("capslock") !== -1)
                    found.push(get(i, "filePath") + "/brightness");
            }
            root.sources = found;
            root.refresh();
        }
    }
}
