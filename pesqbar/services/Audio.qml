pragma Singleton

import Quickshell

// What to call a PipeWire node on screen. The sound panel and the per app list
// both need it and both had the same copy of it, which is one copy too many for
// a list of places to look.
Singleton {
    id: root

    // In order of how much the node meant it. An application says who it is in
    // its own properties first; the node's own names are the fallback for a
    // device that never claimed one.
    readonly property var nameKeys: ["application.name", "media.name", "application.process.binary", "node.description", "node.name"]

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
}
