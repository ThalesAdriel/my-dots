pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/components"

Column {
    id: pageRoot

    readonly property string keybindsPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/hypr/hyprland/keybinds.lua"
    readonly property var categoryOrder: [
        "Apps & Launchers",
        "Window Management",
        "Workspaces",
        "Media & Audio",
        "Screenshots & Power"
    ]

    property var entries: []
    property bool loaded: false
    property string loadError: ""

    readonly property string localNeedle: filterField.text.trim().toLowerCase()

    readonly property var sections: {
        const buckets = {};
        for (let i = 0; i < pageRoot.categoryOrder.length; i++)
            buckets[pageRoot.categoryOrder[i]] = [];

        for (let i = 0; i < pageRoot.entries.length; i++) {
            const item = pageRoot.entries[i];
            const cat = buckets[item.category] !== undefined ? item.category : "Apps & Launchers";
            buckets[cat].push(item);
        }

        const out = [];
        for (let i = 0; i < pageRoot.categoryOrder.length; i++) {
            const title = pageRoot.categoryOrder[i];
            if (buckets[title].length > 0)
                out.push({ title: title, items: buckets[title] });
        }
        return out;
    }

    readonly property int localMatchCount: {
        if (pageRoot.localNeedle === "")
            return pageRoot.entries.length;
        let count = 0;
        for (let i = 0; i < pageRoot.entries.length; i++) {
            if (pageRoot.matchesLocal(pageRoot.entries[i]))
                count++;
        }
        return count;
    }

    function matchesLocal(item: var): bool {
        if (pageRoot.localNeedle === "")
            return true;
        const haystack = (item.combo + " " + item.action + " " + item.category).toLowerCase();
        return haystack.indexOf(pageRoot.localNeedle) !== -1;
    }

    function splitTopLevelArgs(argString: string): var {
        const args = [];
        let cur = "";
        let paren = 0;
        let brace = 0;
        let quote = "";
        let escaped = false;

        for (let i = 0; i < argString.length; i++) {
            const ch = argString[i];
            if (quote !== "") {
                cur += ch;
                if (escaped) {
                    escaped = false;
                } else if (ch === "\\") {
                    escaped = true;
                } else if (ch === quote) {
                    quote = "";
                }
                continue;
            }
            if (ch === '"' || ch === "'") {
                quote = ch;
                cur += ch;
            } else if (ch === "(") {
                paren++;
                cur += ch;
            } else if (ch === ")") {
                paren--;
                cur += ch;
            } else if (ch === "{") {
                brace++;
                cur += ch;
            } else if (ch === "}") {
                brace--;
                cur += ch;
            } else if (ch === "," && paren === 0 && brace === 0) {
                args.push(cur.trim());
                cur = "";
            } else {
                cur += ch;
            }
        }
        if (cur.trim() !== "")
            args.push(cur.trim());
        return args;
    }

    function formatKeyToken(token: string): string {
        const t = token.trim();
        const map = {
            "SUPER": "Super",
            "SHIFT": "Shift",
            "CTRL": "Ctrl",
            "ALT": "Alt",
            "space": "Space",
            "Return": "Return",
            "TAB": "Tab",
            "PERIOD": ".",
            "Semicolon": ";",
            "Apostrophe": "'",
            "Minus": "-",
            "Equal": "=",
            "Page_Down": "Page Down",
            "Page_Up": "Page Up",
            "Delete": "Delete",
            "Print": "Print",
            "mouse:272": "Left Click",
            "mouse:273": "Right Click",
            "mouse_down": "Scroll Down",
            "mouse_up": "Scroll Up",
            "XF86MonBrightnessUp": "Brightness Up",
            "XF86MonBrightnessDown": "Brightness Down",
            "XF86AudioRaiseVolume": "Volume Up",
            "XF86AudioLowerVolume": "Volume Down",
            "XF86AudioMute": "Volume Mute",
            "XF86AudioMicMute": "Mic Mute",
            "XF86AudioPlay": "Media Play",
            "XF86AudioPause": "Media Pause",
            "XF86AudioNext": "Media Next",
            "XF86AudioPrev": "Media Previous"
        };
        if (map[t] !== undefined)
            return map[t];
        return t;
    }

    function parseCombo(rawExpr: string): string {
        let expr = rawExpr.trim();
        let hasSuper = false;

        const superMatch = /^super\(\s*"([^"]+)"\s*\)$/.exec(expr);
        if (superMatch) {
            hasSuper = true;
            expr = superMatch[1];
        } else {
            const quotedMatch = /^"([^"]+)"$/.exec(expr);
            if (quotedMatch)
                expr = quotedMatch[1];
        }

        const parts = expr.split("+").map(p => pageRoot.formatKeyToken(p)).filter(p => p !== "");
        if (hasSuper)
            parts.unshift("Super");
        return parts.join(" + ");
    }

    function describeAction(rawExpr: string): var {
        const expr = rawExpr.trim();
        const dirLabels = { l: "left", r: "right", u: "up", d: "down" };

        // Apps & Launchers
        if (/^launcher\(\s*"fuzzel"\s*\)$/.test(expr))
            return { action: "Application launcher (Fuzzel)", category: "Apps & Launchers" };
        if (/launch_first_available\.sh",\s*terminals/.test(expr))
            return { action: "Open terminal", category: "Apps & Launchers" };
        if (/launch_first_available\.sh",\s*browsers/.test(expr))
            return { action: "Open web browser", category: "Apps & Launchers" };
        if (/launch_first_available\.sh",\s*notes/.test(expr))
            return { action: "Open notes (Obsidian)", category: "Apps & Launchers" };
        if (/^run\(\s*"nautilus"\s*\)$/.test(expr))
            return { action: "Open file manager (Nautilus)", category: "Apps & Launchers" };
        if (/^run\(\s*"kitty -1 vis"\s*\)$/.test(expr))
            return { action: "Open terminal editor (vis)", category: "Apps & Launchers" };
        if (/fuzzel-sysmenu\.sh/.test(expr))
            return { action: "System menu", category: "Apps & Launchers" };
        if (/cliphist/.test(expr))
            return { action: "Clipboard history", category: "Apps & Launchers" };
        if (/fuzzel-emoji\.sh/.test(expr))
            return { action: "Emoji picker", category: "Apps & Launchers" };
        if (/hyprpicker/.test(expr))
            return { action: "Color picker (copy to clipboard)", category: "Apps & Launchers" };
        if (/overview toggle/.test(expr))
            return { action: "Toggle workspace overview", category: "Apps & Launchers" };
        if (/settings toggle/.test(expr))
            return { action: "Toggle settings", category: "Apps & Launchers" };

        // Screenshots & Power
        if (/^shot\(\s*"region"\s*,\s*.*screenshot_edit\.sh/.test(expr))
            return { action: "Screenshot region & edit", category: "Screenshots & Power" };
        if (/^shot\(\s*"region"\s*\)$/.test(expr))
            return { action: "Screenshot region", category: "Screenshots & Power" };
        if (/^shot\(\s*"output"\s*\)$/.test(expr))
            return { action: "Screenshot active screen", category: "Screenshots & Power" };
        if (/grim\s/.test(expr))
            return { action: "Screenshot all screens", category: "Screenshots & Power" };
        if (/^power\(\s*"lock"\s*\)$/.test(expr))
            return { action: "Lock screen", category: "Screenshots & Power" };
        if (/^power\(\s*"suspend"\s*\)$/.test(expr))
            return { action: "Suspend system", category: "Screenshots & Power" };
        if (/^power\(\s*"poweroff"\s*\)$/.test(expr))
            return { action: "Power off", category: "Screenshots & Power" };

        // Media & Audio
        if (/audio_output_switch\.sh/.test(expr))
            return { action: "Switch audio output", category: "Media & Audio" };
        if (/brightness\.sh",\s*"--inc"/.test(expr))
            return { action: "Increase brightness", category: "Media & Audio" };
        if (/brightness\.sh",\s*"--dec"/.test(expr))
            return { action: "Decrease brightness", category: "Media & Audio" };
        if (/volume_control\.sh",\s*"--inc"/.test(expr))
            return { action: "Increase volume", category: "Media & Audio" };
        if (/volume_control\.sh",\s*"--dec"/.test(expr))
            return { action: "Decrease volume", category: "Media & Audio" };
        if (/volume_control\.sh",\s*"--toggle-mic"/.test(expr))
            return { action: "Toggle microphone mute", category: "Media & Audio" };
        if (/volume_control\.sh",\s*"--toggle"/.test(expr))
            return { action: "Toggle mute", category: "Media & Audio" };
        if (/media playPause/.test(expr))
            return { action: "Play / pause media", category: "Media & Audio" };
        if (/media next/.test(expr))
            return { action: "Next media track", category: "Media & Audio" };
        if (/media previous/.test(expr))
            return { action: "Previous media track", category: "Media & Audio" };

        // Window Management
        if (/^hl\.dsp\.window\.close\(\)$/.test(expr))
            return { action: "Close active window", category: "Window Management" };
        if (/hyprctl kill/.test(expr))
            return { action: "Force kill window", category: "Window Management" };
        if (/fullscreen\(\{\s*mode\s*=\s*"fullscreen"\s*\}\)/.test(expr))
            return { action: "Toggle fullscreen", category: "Window Management" };
        if (/fullscreen\(\{\s*mode\s*=\s*"maximized"\s*\}\)/.test(expr))
            return { action: "Toggle maximize", category: "Window Management" };
        if (/^hl\.dsp\.window\.pin\(\)$/.test(expr))
            return { action: "Pin / unpin floating window", category: "Window Management" };
        if (/hl\.dsp\.window\.float/.test(expr))
            return { action: "Toggle floating", category: "Window Management" };
        if (/^hl\.dsp\.window\.drag\(\)$/.test(expr))
            return { action: "Drag window", category: "Window Management" };
        if (/^hl\.dsp\.window\.resize\(\)$/.test(expr))
            return { action: "Resize window", category: "Window Management" };

        const focusDir = /hl\.dsp\.focus\(\{\s*direction\s*=\s*"([lrud])"\s*\}\)/.exec(expr);
        if (focusDir)
            return { action: "Focus window " + dirLabels[focusDir[1]], category: "Window Management" };

        const moveDir = /hl\.dsp\.window\.move\(\{\s*direction\s*=\s*"([lrud])"\s*\}\)/.exec(expr);
        if (moveDir)
            return { action: "Move window " + dirLabels[moveDir[1]], category: "Window Management" };

        if (/splitratio\s*-/.test(expr))
            return { action: "Shrink split ratio", category: "Window Management" };
        if (/splitratio\s*\+/.test(expr))
            return { action: "Grow split ratio", category: "Window Management" };
        if (/^zoom\(\s*-/.test(expr))
            return { action: "Zoom out", category: "Window Management" };
        if (/^zoom\(\s*\+?[\d.]/.test(expr))
            return { action: "Zoom in", category: "Window Management" };

        // Workspaces
        if (/hl\.dsp\.focus\(\{\s*workspace\s*=\s*"r\+1"\s*\}\)/.test(expr))
            return { action: "Next workspace", category: "Workspaces" };
        if (/hl\.dsp\.focus\(\{\s*workspace\s*=\s*"r-1"\s*\}\)/.test(expr))
            return { action: "Previous workspace", category: "Workspaces" };
        if (/hl\.dsp\.focus\(\{\s*workspace\s*=\s*"\+1"\s*\}\)/.test(expr))
            return { action: "Next active workspace", category: "Workspaces" };
        if (/hl\.dsp\.focus\(\{\s*workspace\s*=\s*"-1"\s*\}\)/.test(expr))
            return { action: "Previous active workspace", category: "Workspaces" };
        if (/hl\.dsp\.window\.move\(\{\s*workspace\s*=\s*"r\+1"/.test(expr))
            return { action: "Move window to next workspace", category: "Workspaces" };
        if (/hl\.dsp\.window\.move\(\{\s*workspace\s*=\s*"r-1"/.test(expr))
            return { action: "Move window to previous workspace", category: "Workspaces" };
        if (/toggle_special\(\s*"magic"\s*\)/.test(expr))
            return { action: "Toggle scratchpad", category: "Workspaces" };
        if (/special:magic/.test(expr))
            return { action: "Send window to scratchpad", category: "Workspaces" };

        // Generic fallbacks for user-added binds
        const runMatch = /^(?:run|launcher)\(\s*"([^"]+)"\s*\)$/.exec(expr);
        if (runMatch)
            return { action: runMatch[1], category: "Apps & Launchers" };

        const scriptMatch = /^(?:script|menu)\(\s*"([^"]+)"/.exec(expr);
        if (scriptMatch)
            return { action: scriptMatch[1], category: "Apps & Launchers" };

        return { action: expr, category: "Apps & Launchers" };
    }

    function parseKeybinds(text: string): var {
        const lines = (text || "").split(/\r?\n/);
        const result = [];
        let inWorkspaceLoop = false;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line === "" || line.indexOf("--") === 0)
                continue;

            if (/^for\s+\w+\s*=\s*1\s*,\s*10\s+do\b/.test(line)) {
                inWorkspaceLoop = true;
                result.push({
                    combo: "Super + 1..0",
                    action: "Switch to workspace 1–10",
                    category: "Workspaces"
                });
                result.push({
                    combo: "Super + Alt + 1..0",
                    action: "Move window to workspace 1–10",
                    category: "Workspaces"
                });
                continue;
            }

            if (inWorkspaceLoop) {
                if (/^end\b/.test(line))
                    inWorkspaceLoop = false;
                continue;
            }

            const bindMatch = /^hl\.bind\((.*)\)\s*$/.exec(line);
            if (!bindMatch)
                continue;

            const args = pageRoot.splitTopLevelArgs(bindMatch[1]);
            if (args.length < 2)
                continue;

            const combo = pageRoot.parseCombo(args[0]);
            const info = pageRoot.describeAction(args[1]);
            if (combo === "" || info.action === "")
                continue;

            result.push({
                combo: combo,
                action: info.action,
                category: info.category
            });
        }

        return result;
    }

    spacing: 18

    // Local filter field (hidden while the sidebar's global search is active).
    Item {
        width: parent.width
        height: visible ? 30 : 0
        visible: !SettingsContext.searching

        TextField {
            id: filterField

            anchors.left: parent.left
            anchors.right: clearButton.visible ? clearButton.left : parent.right
            anchors.rightMargin: clearButton.visible ? 6 : 0
            anchors.verticalCenter: parent.verticalCenter

            placeholder: "Filter shortcuts by key or action..."
        }

        PanelButton {
            id: clearButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: filterField.text !== ""
            implicitWidth: 30
            implicitHeight: 30
            glyph: Glyphs.xmark
            onActivated: filterField.clear()
        }
    }

    PanelMessage {
        width: parent.width
        visible: pageRoot.loadError !== "" && !SettingsContext.searching
        warning: true
        text: pageRoot.loadError
    }

    PanelMessage {
        width: parent.width
        visible: pageRoot.loaded && pageRoot.loadError === "" && pageRoot.localMatchCount === 0 && !SettingsContext.searching
        text: pageRoot.localNeedle !== "" ? "No shortcuts match \"" + filterField.text.trim() + "\"." : "No keybinds found in keybinds.lua."
    }

    Repeater {
        model: pageRoot.sections

        delegate: Group {
            id: sectionGroup

            required property var modelData

            readonly property int localVisibleCount: {
                if (pageRoot.localNeedle === "")
                    return sectionGroup.modelData.items.length;
                let count = 0;
                const list = sectionGroup.modelData.items;
                for (let i = 0; i < list.length; i++) {
                    if (pageRoot.matchesLocal(list[i]))
                        count++;
                }
                return count;
            }

            title: sectionGroup.modelData.title
            visible: SettingsContext.searching ? sectionGroup.hit : sectionGroup.localVisibleCount > 0

            Repeater {
                model: sectionGroup.modelData.items

                delegate: Item {
                    id: bindRow

                    required property var modelData

                    readonly property string searchText: bindRow.modelData.combo + " " + bindRow.modelData.action
                    readonly property bool hit: SettingsContext.shows(bindRow, bindRow.searchText)
                    readonly property bool shown: SettingsContext.searching ? bindRow.hit : pageRoot.matchesLocal(bindRow.modelData)
                    readonly property var keyParts: bindRow.modelData.combo.split(" + ")

                    width: parent.width
                    height: bindRow.shown ? 32 : 0
                    visible: bindRow.shown

                    Text {
                        anchors.left: parent.left
                        anchors.right: keysRow.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter

                        text: bindRow.modelData.action
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Row {
                        id: keysRow

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        Repeater {
                            model: bindRow.keyParts

                            delegate: Rectangle {
                                id: keycap

                                required property string modelData

                                width: capText.implicitWidth + 12
                                height: 22
                                radius: Theme.radius
                                color: Theme.fillTrack
                                border.width: 1
                                border.color: Theme.cardBorder

                                Text {
                                    id: capText

                                    anchors.centerIn: parent
                                    text: keycap.modelData
                                    textFormat: Text.PlainText
                                    color: Theme.textPrimary
                                    font.family: Theme.monoFamily
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    FileView {
        id: keybindsFile

        path: pageRoot.keybindsPath
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: keybindsFile.reload()

        onLoaded: {
            pageRoot.entries = pageRoot.parseKeybinds(keybindsFile.text());
            pageRoot.loadError = "";
            pageRoot.loaded = true;
        }

        onLoadFailed: {
            pageRoot.entries = [];
            pageRoot.loadError = "Could not read " + pageRoot.keybindsPath;
            pageRoot.loaded = true;
        }
    }
}
