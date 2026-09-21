pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    property string base: ""
    property int percent: -1
    property string powerState: ""

    readonly property bool available: root.percent >= 0
    readonly property bool charging: root.powerState === "Charging"
    readonly property string label: !root.available ? "" : root.charging ? "(+) " + root.percent + "%" : root.percent + "% remaining"

    function read(path) {
        if (probe.path === path)
            probe.reload();
        else
            probe.path = path;
        return probe.text();
    }

    function refresh() {
        if (root.base.length === 0)
            return;

        const capacity = parseInt(root.read(root.base + "/capacity"), 10);
        if (isNaN(capacity)) {
            root.percent = -1;
            return;
        }

        root.percent = capacity;
        root.powerState = (root.read(root.base + "/status") || "").trim();
    }

    FileView {
        id: probe
        blockLoading: true
        printErrors: false
    }

    FolderListModel {
        id: supplies
        folder: "file:///sys/class/power_supply"
        showFiles: false
        showDirs: true
        showDotAndDotDot: false
        sortField: FolderListModel.Name

        onCountChanged: {
            for (let i = 0; i < count; ++i) {
                const path = get(i, "filePath");
                const type = (root.read(path + "/type") || "").trim();
                if (type === "Battery") {
                    root.base = path;
                    root.refresh();
                    return;
                }
            }
        }
    }

    Connections {
        target: Clock
        function onNowChanged() {
            root.refresh();
        }
    }
}
