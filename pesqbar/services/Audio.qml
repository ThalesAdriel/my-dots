pragma Singleton

import Quickshell

// What to call a PipeWire node on screen: the sound panel and the per app list both need it and both had their own copy.
Singleton {
    id: root

    // In order of how much the node meant it: an application's own properties first, the node's own names as the fallback.
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
