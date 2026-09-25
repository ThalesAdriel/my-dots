pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Which application opens what: links, mail, folders, text, pictures, video, music and PDFs. The defaults live in ~/.config/mimeapps.list and are read and written through gio, the same way GNOME's own settings write them, so xdg-open, portals and every GTK app agree with what is picked here. gio only lists the applications for a type once one is the default, so the candidates come from the desktop files themselves.
Singleton {
    id: root

    // The first type is the one a category is shown by; picking an application makes it the default for every type in the list it says it can open.
    readonly property var categories: [
        {
            key: "browser",
            label: "Web browser",
            types: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html", "application/xhtml+xml"]
        },
        {
            key: "mail",
            label: "Email",
            types: ["x-scheme-handler/mailto"]
        },
        {
            key: "files",
            label: "File manager",
            types: ["inode/directory"]
        },
        {
            key: "text",
            label: "Text editor",
            types: ["text/plain"]
        },
        {
            key: "images",
            label: "Images",
            types: ["image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp", "image/tiff"]
        },
        {
            key: "video",
            label: "Video",
            types: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"]
        },
        {
            key: "music",
            label: "Music",
            types: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-vorbis+ogg", "audio/mp4", "audio/x-wav"]
        },
        {
            key: "pdf",
            label: "PDF documents",
            types: ["application/pdf"]
        }
    ]

    // Desktop file id to { name, types }, for everything that says what it opens and asks to be shown.
    property var apps: ({})

    // Category key to the desktop file id in use, or "" when nothing is set.
    property var current: ({})

    property bool available: true
    property string lastError: ""

    // Every desktop file on the data dirs, first one of an id wins as the spec says, printed as id, name and types. A file in a subfolder gets the folder in its id, joined with a dash. Hidden and NoDisplay ones are left out: the first means deleted, the second a helper nobody picks by name.
    readonly property string scanScript: `command -v gio >/dev/null 2>&1 || exit 127
IFS=:
for dir in "\${XDG_DATA_HOME:-$HOME/.local/share}" \${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
    [ -d "$dir/applications" ] || continue
    (cd "$dir/applications" && find -L . -name '*.desktop' -type f -exec awk '
        function emit() { if (types != "" && kind == "Application" && !hidden) printf "a\\t%s\\t%s\\t%s\\n", id, name, types }
        FNR == 1 { if (id != "") emit(); id = substr(FILENAME, 3); gsub("/", "-", id); section = ""; name = ""; types = ""; kind = ""; hidden = 0 }
        /^\\[/ { section = $0; next }
        section != "[Desktop Entry]" { next }
        /^Name=/ && name == "" { name = substr($0, 6) }
        /^MimeType=/ { types = substr($0, 10) }
        /^Type=/ { kind = substr($0, 6) }
        /^(Hidden|NoDisplay)=true/ { hidden = 1 }
        END { if (id != "") emit() }
    ' {} +)
done
exit 0`

    // The default for each category's first type, one gio call each, as "d <key> <id>".
    readonly property string queryScript: `command -v gio >/dev/null 2>&1 || exit 127
export LC_ALL=C
while [ $# -gt 1 ]; do
    printf 'd\\t%s\\t%s\\n' "$1" "$(gio mime "$2" 2>/dev/null | sed -n '1s/^Default application for .*: //p')"
    shift 2
done`

    function nameOf(id: string): string {
        const app = root.apps[id];
        return app !== undefined && app.name !== "" ? app.name : id.replace(/\.desktop$/, "");
    }

    // The applications that say they open the category's first type, by name.
    function candidates(key: string): var {
        const category = root.categories.find(entry => entry.key === key);
        if (!category)
            return [];
        return Object.keys(root.apps).filter(id => root.apps[id].types.indexOf(category.types[0]) !== -1).sort((left, right) => root.nameOf(left).localeCompare(root.nameOf(right)));
    }

    function refresh(): void {
        if (scanProcess.running)
            return;
        scanProcess.running = true;
    }

    function set(key: string, id: string): void {
        const category = root.categories.find(entry => entry.key === key);
        const app = root.apps[id];

        // Ids come off the filesystem, and only a plain desktop file name reaches gio.
        if (!category || app === undefined || !/^[A-Za-z0-9][A-Za-z0-9_.+-]*\.desktop$/.test(id) || setProcess.running)
            return;

        const types = category.types.filter(type => app.types.indexOf(type) !== -1);
        root.lastError = "";
        setProcess.command = ["sh", "-c", 'id=$1; shift; for type; do gio mime "$type" "$id" >/dev/null || exit 1; done', "qsbar-default-apps", id].concat(types);
        setProcess.running = true;
    }

    Process {
        id: scanProcess

        command: ["sh", "-c", root.scanScript, "qsbar-default-apps"]

        stdout: StdioCollector {
            onStreamFinished: {
                const apps = {};
                for (const line of this.text.split("\n")) {
                    const fields = line.split("\t");
                    if (fields[0] !== "a" || fields.length < 4 || apps[fields[1]] !== undefined)
                        continue;
                    apps[fields[1]] = {
                        name: fields[2],
                        types: fields[3].split(";").filter(type => type !== "")
                    };
                }
                root.apps = apps;
            }
        }

        onExited: exitCode => {
            root.available = exitCode !== 127;
            if (!root.available) {
                root.lastError = "gio is not installed (it comes with glib2), so the defaults cannot be read or changed.";
                return;
            }

            const pairs = [];
            for (const category of root.categories)
                pairs.push(category.key, category.types[0]);
            queryProcess.command = ["sh", "-c", root.queryScript, "qsbar-default-apps"].concat(pairs);
            queryProcess.running = true;
        }
    }

    Process {
        id: queryProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const current = {};
                for (const line of this.text.split("\n")) {
                    const fields = line.split("\t");
                    if (fields[0] === "d" && fields.length >= 3)
                        current[fields[1]] = fields[2].trim();
                }
                root.current = current;
            }
        }
    }

    Process {
        id: setProcess

        stderr: StdioCollector {
            onStreamFinished: {
                const message = this.text.trim();
                if (message !== "")
                    root.lastError = message.split("\n")[0];
            }
        }

        onExited: root.refresh()
    }
}
