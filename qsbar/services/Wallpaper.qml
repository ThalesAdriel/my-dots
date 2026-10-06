pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"

// The desktop wallpaper, through awww.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/home"
    readonly property string folder: Settings.wallpaperFolder.startsWith("~/") ? root.home + Settings.wallpaperFolder.slice(1) : Settings.wallpaperFolder

    // Every image directly in the folder, as absolute paths.
    property var images: []

    // A small copy of each picture, saved the first time a grid decodes it.
    readonly property string thumbDir: Quickshell.cachePath("thumbnails")

    // Picture path to the name its thumbnail has or will have, and the names already on disk.
    property var thumbNames: ({})
    property var thumbsOnDisk: ({})

    // The listing of what is already in the cache, then the pictures with what their thumbnails are named after.
    readonly property string scanScript: `mkdir -p "$2" && find "$2" -maxdepth 1 -name "*.jpg" -printf "t %f\\n"
find -L "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \\) -printf "i %T@ %s %p\\n"`

    function thumbnail(path: string): string {
        const name = root.thumbNames[path];
        return name !== undefined && root.thumbsOnDisk[name] ? root.fileUrl(root.thumbDir + "/" + name) : "";
    }

    // A tile hands over the picture it has just decoded, and what it drew is saved as the thumbnail.
    function keep(path: string, item: Item): void {
        const name = root.thumbNames[path];
        if (name === undefined)
            return;

        item.grabToImage(result => {
            // Recorded in place rather than reassigned.
            if (result.saveToFile(root.thumbDir + "/" + name))
                root.thumbsOnDisk[name] = true;
        }, Qt.size(256, Math.round(256 * item.height / item.width)));
    }

    // Output name to the image it is showing, as awww reports it.
    property var current: ({})

    // Every output awww is drawing on, whether or not it has an image yet.
    property var outputs: []

    property bool available: true
    property string lastError: ""

    readonly property var transitions: [
        {
            value: "none",
            label: "None"
        },
        {
            value: "fade",
            label: "Fade"
        },
        {
            value: "wipe",
            label: "Wipe"
        },
        {
            value: "grow",
            label: "Grow"
        },
        {
            value: "outer",
            label: "Outer"
        },
        {
            value: "wave",
            label: "Wave"
        },
        {
            value: "random",
            label: "Random"
        }
    ]

    // Each segment escaped on its own.
    function fileUrl(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // Only an absolute folder reaches find.
    function scan(): void {
        scanProcess.running = false;
        if (!root.folder.startsWith("/")) {
            root.images = [];
            return;
        }
        scanProcess.command = ["sh", "-c", root.scanScript, "qsbar-wallpapers", root.folder, root.thumbDir];
        scanProcess.running = true;
    }

    function refresh(): void {
        if (!queryProcess.running)
            queryProcess.running = true;
    }

    // "DP-1: 1920x1080, scale: 1, currently displaying: image: /path/to/w.jpg", one line per output.
    function parse(text: string): void {
        const shown = {};
        const names = [];
        for (const line of text.split("\n")) {
            const output = line.match(/(?:^|\s)([^\s:]+): \d+x\d+/);
            if (!output)
                continue;
            names.push(output[1]);

            const image = line.match(/currently displaying: image: (.+)$/);
            if (image)
                shown[output[1]] = image[1].trim();
        }

        root.outputs = names.sort();
        root.current = shown;
        root.available = true;
    }

    // awww calls waiting their turn.
    property var queue: []

    // An empty output means every one of them; several can be named with commas.
    function apply(path: string, output: string): void {
        // awww animates at 30 fps unless told otherwise, which steps visibly on a high refresh panel.
        const command = ["awww", "img", path, "--resize", Settings.wallpaperResize, "--transition-type", Settings.wallpaperTransition, "--transition-duration", Settings.wallpaperTransitionSeconds.toFixed(1), "--transition-fps", "60"];
        if (output !== "")
            command.push("--outputs", output);

        // Drawn as chosen straight away rather than after the transition and a query.
        const next = Object.assign({}, root.current);
        for (const name of (output !== "" ? output.split(",") : root.outputs))
            next[name] = path;
        root.current = next;

        root.lastError = "";
        root.queue = root.queue.concat([command]);
        root.pump();
    }

    // Everything on screen drawn again, for a setting like the scaling that only shows once awww redraws.
    function reapply(): void {
        const byPath = {};
        for (const name of root.outputs) {
            const path = root.current[name];
            if (path !== undefined)
                byPath[path] = (byPath[path] || []).concat([name]);
        }
        for (const path of Object.keys(byPath))
            root.apply(path, byPath[path].join(","));
    }

    function pump(): void {
        if (applyProcess.running || root.queue.length === 0)
            return;
        applyProcess.command = root.queue[0];
        root.queue = root.queue.slice(1);
        applyProcess.running = true;
    }

    onFolderChanged: root.scan()

    // ponytail: one level deep and every match drawn at once; a folder of thousands of images wants a GridView over this instead of a Repeater.
    Process {
        id: scanProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const images = [];
                const names = {};
                const onDisk = {};
                for (const line of this.text.split("\n")) {
                    if (line.startsWith("t ")) {
                        onDisk[line.slice(2)] = true;
                    } else if (line.startsWith("i ")) {
                        // "i <mtime> <size> <path>", and the path may have spaces of its own.
                        const path = line.split(" ").slice(3).join(" ");
                        images.push(path);
                        names[path] = Qt.md5(line) + ".jpg";
                    }
                }

                root.thumbNames = names;
                root.thumbsOnDisk = onDisk;

                // Every page that shows a grid scans as it opens.
                images.sort();
                if (images.join("\n") !== root.images.join("\n"))
                    root.images = images;
            }
        }
    }

    Process {
        id: queryProcess

        command: ["awww", "query"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.available = false;
                root.current = ({});
                root.outputs = [];
            }
        }
    }

    Process {
        id: applyProcess

        stderr: StdioCollector {
            onStreamFinished: {
                const message = this.text.trim();
                if (message !== "")
                    root.lastError = message.split("\n")[0];
            }
        }

        // The next in line, or once the line is empty a read back of what awww actually took.
        onExited: Qt.callLater(() => root.queue.length > 0 ? root.pump() : root.refresh())
    }
}
