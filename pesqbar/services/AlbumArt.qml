pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The cover the player is pointing at, as a file on this machine.
//
// Every other image in the shell is held to a local path on purpose: an Image
// fetches a remote URL as readily as it opens a file, and the string naming one
// arrives over the session bus rather than being something the shell chose.
// `Notifications.localImage` drops everything that is not already local for that
// reason, and the player card was written the same way — but Spotify only ever
// names its covers as https URLs on its own CDN, so the card had nothing local
// left to draw and fell back to the play glyph on every track.
//
// The fetch happens here instead of inside the Image. curl is handed one URL
// with a scheme this file allows, a size cap and a deadline, and writes the
// result under the cache directory; what the card loads is always a file on
// disk, and the shell's own loader is never pointed at a string that came off
// the bus. What no amount of checking takes away is that the request leaves the
// machine at all: a player naming a cover on a server it controls learns the
// same thing any web page learns. That is a trade this module makes and the
// notification images do not, because a player is something the user started
// and a cover is the whole point of the card, while a notification can come
// from any process that reaches the bus and has an icon either way.
Singleton {
    id: root

    // One file per URL, named by its digest rather than by the track, so a song
    // that comes round again is drawn from disk and the same cover shared by a
    // whole album is only ever fetched once. Nothing here expires: the files are
    // tens of kilobytes and `rm -rf` on the directory is the whole cleanup.
    readonly property string cacheDir: Quickshell.cachePath("album-art")

    // The only two schemes a cover is fetched over. Everything else — a data:
    // blob, an ftp: URL, a bare word that is not a path at all — is not a cover
    // this shell goes looking for.
    readonly property var remoteSchemes: ["http", "https"]

    // A cover is tens of kilobytes. Nothing calling itself one has any business
    // being megabytes, and nothing worth drawing on a card that changes with the
    // track is worth waiting on for longer than this.
    readonly property int maximumBytes: 4000000
    readonly property int timeoutSeconds: 15

    // Every URL asked for, mapped to the file it landed in, or to "" for one
    // that could not be fetched. The failures are kept as well as the successes:
    // without them the binding that asked would find nothing there, ask again,
    // and keep curl going for as long as the track was on.
    property var fetched: ({})

    // What is waiting on curl and what it is on. One at a time on purpose: the
    // normal case is several cards on several screens asking for the same cover
    // at the same moment, not a queue of different ones.
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

    // The scheme is the whole check, the same way `Notifications.safeLink` does
    // it: a URL with no scheme is a bare path that is not one, and a scheme that
    // is not named above is refused rather than handed to curl to interpret.
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

    // What to hand an Image for this track, or "" while there is nothing to hand
    // it yet. A remote cover comes back empty the first time and again as a path
    // once curl has it: the map changing is what re-runs the binding that asked,
    // so the card never has to poll for it.
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

    // The URL and the file it is going to are arguments rather than anything
    // pasted into the script, so a cover named with a quote or a space in it is
    // a filename and never a second command, and `--` keeps a URL that starts
    // with a dash from reaching curl as an option. Redirects are followed but
    // only ever to the same two schemes, so a cover that answers with a 302 to
    // a file:// URL is refused there as well as here.
    //
    // The transfer lands beside the file it will become and is moved into place
    // once it is whole. A cover that failed half way would otherwise be cached
    // as a truncated image, and the digest name means nothing would ever go back
    // for it.
    readonly property string script: `set -e
mkdir -p "$(dirname "$2")"
if [ ! -s "$2" ]; then
    trap 'rm -f "$2.part"' EXIT
    curl -fsSL --proto "=http,https" --proto-redir "=http,https" --max-time ${root.timeoutSeconds} --max-filesize ${root.maximumBytes} -o "$2.part" -- "$1"
    mv -f "$2.part" "$2"
fi`

    Process {
        id: fetch

        // Through sh rather than straight at curl for the reason the screenshot
        // editor is: a machine without curl on it fails with a line in the
        // shell's log rather than silently drawing no cover for the rest of the
        // session.
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
