pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// What to call a PipeWire node on screen, and how to route app streams between sinks.
Singleton {
    id: root

    // In order of how much the node meant it.
    readonly property var nameKeys: ["application.name", "media.name", "application.process.binary", "node.description", "node.name"]

    // Available output sinks (non-stream audio sinks).
    readonly property var sinks: {
        if (!Pipewire.nodes)
            return [];
        return Pipewire.nodes.values.filter(node => node && node.isSink && !node.isStream && node.audio !== null);
    }

    // Stream node id -> sink node id for explicit moves made in this session.
    property var streamTargets: ({})

    function describe(node: var): string {
        if (!node)
            return "Unknown";

        const candidates = [];
        const properties = node.properties;

        if (properties) {
            for (const key of root.nameKeys)
                candidates.push(properties[key]);
        }

        candidates.push(node.description, node.nickname, node.name);

        for (const candidate of candidates) {
            if (typeof candidate === "string" && candidate.length > 0)
                return candidate;
        }

        return "Unknown";
    }

    function currentSinkFor(streamNode: var): var {
        if (!streamNode || root.sinks.length === 0)
            return null;

        const routedId = root.streamTargets[streamNode.id];
        if (routedId !== undefined) {
            for (const sink of root.sinks) {
                if (sink.id === routedId)
                    return sink;
            }
        }

        const props = streamNode.properties;
        const target = props ? (props["target.object"] || props["node.target"] || "") : "";
        if (target !== "") {
            const targetStr = String(target);
            for (const sink of root.sinks) {
                const serial = sink.properties && sink.properties["object.serial"] !== undefined ? String(sink.properties["object.serial"]) : "";
                if (targetStr === serial || targetStr === sink.name || targetStr === String(sink.id))
                    return sink;
            }
        }

        const def = Pipewire.defaultAudioSink;
        if (def) {
            for (const sink of root.sinks) {
                if (sink.id === def.id)
                    return sink;
            }
        }

        return root.sinks[0];
    }

    function nextSinkFor(streamNode: var): var {
        if (root.sinks.length < 2)
            return null;

        const current = root.currentSinkFor(streamNode);
        let idx = -1;
        if (current) {
            for (let i = 0; i < root.sinks.length; i++) {
                if (root.sinks[i].id === current.id) {
                    idx = i;
                    break;
                }
            }
        }
        return root.sinks[(idx + 1) % root.sinks.length];
    }

    // Route a PipeWire playback stream to a target sink via pw-metadata (or pactl fallback), zero idle overhead.
    function moveStreamToSink(streamNode: var, sinkNode: var): bool {
        if (!streamNode || !sinkNode)
            return false;

        const streamId = Number(streamNode.id);
        if (!isFinite(streamId) || streamId <= 0)
            return false;

        const serial = sinkNode.properties && sinkNode.properties["object.serial"] !== undefined ? String(sinkNode.properties["object.serial"]) : "";
        const sinkName = sinkNode.name ? String(sinkNode.name) : "";
        const target = serial !== "" ? serial : sinkName;
        if (target === "")
            return false;

        const nextTargets = Object.assign({}, root.streamTargets);
        nextTargets[streamId] = sinkNode.id;
        root.streamTargets = nextTargets;

        Quickshell.execDetached([
            "sh", "-c",
            'if command -v pw-metadata >/dev/null 2>&1; then exec pw-metadata -n default "$1" target.object "$2"; elif command -v pactl >/dev/null 2>&1 && [ -n "$3" ]; then exec pactl move-sink-input "$1" "$3"; fi',
            "qsbar-audio-route",
            String(Math.round(streamId)),
            target,
            sinkName
        ]);
        return true;
    }
}
