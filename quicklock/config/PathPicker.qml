import QtQuick
import Quickshell.Io

Process {
    id: root

    property var candidates: []
    property string result: ""

    command: ["sh", "-c", "for f in \"$@\"; do [ -r \"$f\" ] && { printf %s \"$f\"; exit 0; }; done", "quicklock"].concat(root.candidates)

    stdout: StdioCollector {
        id: sink
        onStreamFinished: root.result = sink.text
    }

    // The list is assembled out of the config file, which lands after the bindings around it have been evaluated once already, so it is rebuilt on the way up and again on every edit while the file is watched. callLater collapses a burst of rebuilds into a single pass over the disk, and defers past construction on its own, which is the whole of what the ready flag here used to do by hand. A Timer would have been the other way round, but Process has no default property to hang one off.
    onCandidatesChanged: Qt.callLater(root.probe)

    function probe() {
        root.running = false;
        if (root.candidates.length > 0)
            root.running = true;
    }
}
