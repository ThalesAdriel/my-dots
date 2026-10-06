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

    // The list is assembled out of the config file.
    onCandidatesChanged: Qt.callLater(root.probe)

    function probe() {
        root.running = false;
        if (root.candidates.length > 0)
            root.running = true;
    }
}
