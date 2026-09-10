pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The cover the player points at, as a local file: Spotify only ever names https URLs, so curl fetches it under a scheme allowlist, size cap and deadline rather than pointing an Image at a string off the bus. The request does leave the machine, a trade a user-started player earns and a notification does not.
Singleton {
    id: root

    // One file per URL named by its digest, so a repeated track is drawn from disk and an album's shared cover is fetched once; nothing expires, and rm -rf on the directory is the cleanup.
    readonly property string cacheDir: Quickshell.cachePath("album-art")

    // The only two schemes a cover is fetched over; a data: blob or an ftp: URL is not a cover this shell goes looking for.
    readonly property var remoteSchemes: ["http", "https"]

    // A cover is tens of kilobytes: nothing larger is one, and nothing worth waiting on longer than this.
    readonly property int maximumBytes: 4000000
    readonly property int timeoutSeconds: 15

    // Every URL asked for, mapped to the file it landed in or to "" for a failure; failures are kept so the binding does not ask again and keep curl going.
    property var fetched: ({})

    // What is waiting on curl and what it is on: one at a time, since the normal case is several cards asking for the same cover at once.
    property var queue: []
    property string current: ""

    function localArt(source: string): string {
        if (!source)
            return "";

        const value = String(source);
        if (value.startsWith("/") || value.startsWith("file://") || value.startsWith("image://"))
            return value;

        return "";
    }

    // The scheme is the whole check, as in Notifications.safeLink: no scheme is a bare path, and an unlisted one is refused rather than handed to curl to interpret.
    function remoteArt(source: string): string {
        const value = String(source);
        const scheme = value.match(/^([a-zA-Z][a-zA-Z0-9+.-]*):\/\//);
        if (!scheme)
            return "";

        return root.remoteSchemes.indexOf(scheme[1].toLowerCase()) !== -1 ? value : "";
    }

    function cacheFile(url: string): string {
        return root.cacheDir + "/" + Qt.md5(url);
    }

    // What to hand an Image for this track, or "" while there is nothing yet; the map changing re-runs the binding, so the card never polls.
    function art(source: string): string {
        if (!source)
            return "";

        const local = root.localArt(source);
        if (local !== "")
            return local;

        const url = root.remoteArt(source);
        if (url === "")
            return "";

        const file = root.fetched[url];
        if (file !== undefined)
            return file;

        root.enqueue(url);
        return "";
    }

    function enqueue(url: string): void {
        if (root.current === url || root.queue.indexOf(url) !== -1)
            return;

        root.queue = root.queue.concat(url);
        root.start();
    }

    function start(): void {
        if (fetch.running || root.current !== "" || root.queue.length === 0)
            return;

        root.current = root.queue[0];
        root.queue = root.queue.slice(1);
        fetch.running = true;
    }

    function settle(url: string, file: string): void {
        const next = Object.assign({}, root.fetched);
        next[url] = file;
        root.fetched = next;
    }

    // URL and destination are arguments rather than pasted into the script, and -- keeps a leading dash off curl's option parser; redirects follow only to the same two schemes, and the transfer lands beside its file and moves into place so a half-fetched cover is never cached under its digest.
    readonly property string script: `set -e
mkdir -p "$(dirname "$2")"
if [ ! -s "$2" ]; then
    trap 'rm -f "$2.part"' EXIT
    curl -fsSL --proto "=http,https" --proto-redir "=http,https" --max-time ${root.timeoutSeconds} --max-filesize ${root.maximumBytes} -o "$2.part" -- "$1"
    mv -f "$2.part" "$2"
fi`

    Process {
        id: fetch

        // Through sh rather than straight at curl, so a machine without curl fails with a line in the log rather than silently drawing no cover.
        command: root.current === "" ? [] : ["sh", "-c", root.script, "pesqbar-album-art", root.current, root.cacheFile(root.current)]

        onExited: (exitCode, exitStatus) => {
            const url = root.current;
            root.current = "";

            if (exitCode !== 0)
                console.warn("pesqBar: no album art from", url, "- exit", exitCode);

            root.settle(url, exitCode === 0 ? root.cacheFile(url) : "");
            root.start();
        }
    }
}
