pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: appearancePage

    spacing: 18

    property bool transferOpen: false
    property string transferMode: ""
    property string transferText: ""
    property string transferPath: "~/qsbar-presets.json"
    property bool browsingFile: false
    property string statusMessage: ""
    property bool statusError: false

    readonly property var builtinPresets: [
        {
            name: "Default",
            accentColor: "#e01b24",
            barColor: "#000000",
            surfaceColor: "#000000",
            barOpacity: 0.30,
            panelOpacity: 0.30,
            barRadius: 0,
            panelRadius: 0,
            barBlur: true,
            panelBlur: true,
            outerCorners: true,
            notificationStyle: "integrated"
        },
        {
            name: "Rounded Glass",
            accentColor: "#3584e4",
            barColor: "#11121a",
            surfaceColor: "#11121a",
            barOpacity: 0.45,
            panelOpacity: 0.50,
            barRadius: 13,
            panelRadius: 18,
            barBlur: true,
            panelBlur: true,
            outerCorners: false,
            notificationStyle: "floating"
        },
        {
            name: "Amethyst Blur",
            accentColor: "#9141ac",
            barColor: "#241f31",
            surfaceColor: "#241f31",
            barOpacity: 0.55,
            panelOpacity: 0.60,
            barRadius: 0,
            panelRadius: 0,
            barBlur: true,
            panelBlur: true,
            outerCorners: true,
            notificationStyle: "integrated"
        },
        {
            name: "Emerald Frost",
            accentColor: "#2ec27e",
            barColor: "#1c2226",
            surfaceColor: "#1c2226",
            barOpacity: 0.48,
            panelOpacity: 0.52,
            barRadius: 10,
            panelRadius: 14,
            barBlur: true,
            panelBlur: true,
            outerCorners: false,
            notificationStyle: "floating"
        }
    ]

    function currentSnapshot(name: string): var {
        return {
            name: name,
            accentColor: Settings.accentColor,
            barColor: Settings.barColor,
            surfaceColor: Settings.surfaceColor,
            barOpacity: Settings.barOpacity,
            panelOpacity: Settings.panelOpacity,
            barRadius: Settings.barRadius,
            panelRadius: Settings.panelRadius,
            barBlur: Settings.barBlur,
            panelBlur: Settings.panelBlur,
            outerCorners: Settings.outerCorners,
            notificationStyle: Settings.notificationStyle
        };
    }

    function applyPreset(preset: var): void {
        if (!preset)
            return;
        if (preset.accentColor !== undefined)
            Settings.accentColor = preset.accentColor;
        if (preset.barColor !== undefined)
            Settings.barColor = preset.barColor;
        if (preset.surfaceColor !== undefined)
            Settings.surfaceColor = preset.surfaceColor;
        if (preset.barOpacity !== undefined)
            Settings.barOpacity = preset.barOpacity;
        if (preset.panelOpacity !== undefined)
            Settings.panelOpacity = preset.panelOpacity;
        if (preset.barRadius !== undefined)
            Settings.barRadius = preset.barRadius;
        if (preset.panelRadius !== undefined)
            Settings.panelRadius = preset.panelRadius;
        if (preset.barBlur !== undefined)
            Settings.barBlur = preset.barBlur;
        if (preset.panelBlur !== undefined)
            Settings.panelBlur = preset.panelBlur;
        if (preset.outerCorners !== undefined)
            Settings.outerCorners = preset.outerCorners;
        if (preset.notificationStyle !== undefined)
            Settings.notificationStyle = preset.notificationStyle;
    }

    function savePreset(rawName: string): void {
        const name = rawName.trim();
        if (name === "")
            return;

        const entry = appearancePage.currentSnapshot(name);

        const existing = Array.isArray(Settings.appearancePresets) ? Settings.appearancePresets.slice() : [];
        const matchIndex = existing.findIndex(item => item && item.name === name);
        if (matchIndex >= 0)
            existing[matchIndex] = entry;
        else
            existing.push(entry);
        Settings.appearancePresets = existing;
    }

    function deletePreset(index: int): void {
        if (!Array.isArray(Settings.appearancePresets))
            return;
        const next = Settings.appearancePresets.filter((_, i) => i !== index);
        Settings.appearancePresets = next;
    }

    function sanitizePreset(raw: var): var {
        if (!raw || typeof raw !== "object")
            return null;
        const entry = {
            name: typeof raw.name === "string" && raw.name.trim() !== "" ? raw.name.trim() : "Imported"
        };
        if (typeof raw.accentColor === "string")
            entry.accentColor = raw.accentColor;
        if (typeof raw.barColor === "string")
            entry.barColor = raw.barColor;
        if (typeof raw.surfaceColor === "string")
            entry.surfaceColor = raw.surfaceColor;
        if (typeof raw.barOpacity === "number")
            entry.barOpacity = Math.min(Math.max(raw.barOpacity, 0), 1);
        if (typeof raw.panelOpacity === "number")
            entry.panelOpacity = Math.min(Math.max(raw.panelOpacity, 0.3), 1);
        if (typeof raw.barRadius === "number")
            entry.barRadius = Math.round(Math.min(Math.max(raw.barRadius, 0), 20));
        if (typeof raw.panelRadius === "number")
            entry.panelRadius = Math.round(Math.min(Math.max(raw.panelRadius, 0), 24));
        if (typeof raw.barBlur === "boolean")
            entry.barBlur = raw.barBlur;
        if (typeof raw.panelBlur === "boolean")
            entry.panelBlur = raw.panelBlur;
        if (typeof raw.outerCorners === "boolean")
            entry.outerCorners = raw.outerCorners;
        if (typeof raw.notificationStyle === "string" && (raw.notificationStyle === "integrated" || raw.notificationStyle === "floating"))
            entry.notificationStyle = raw.notificationStyle;
        return entry;
    }

    function importFromJson(rawText: string): bool {
        appearancePage.statusMessage = "";
        appearancePage.statusError = false;
        const trimmed = rawText.trim();
        if (trimmed === "") {
            appearancePage.statusError = true;
            appearancePage.statusMessage = "Nothing to import.";
            return false;
        }

        let parsed = null;
        try {
            parsed = JSON.parse(trimmed);
        } catch (err) {
            appearancePage.statusError = true;
            appearancePage.statusMessage = "Invalid JSON: " + err.message;
            return false;
        }

        const list = Array.isArray(parsed) ? parsed : (parsed && Array.isArray(parsed.presets) ? parsed.presets : [parsed]);
        const existing = Array.isArray(Settings.appearancePresets) ? Settings.appearancePresets.slice() : [];
        let count = 0;
        let lastEntry = null;

        for (let i = 0; i < list.length; i++) {
            const clean = appearancePage.sanitizePreset(list[i]);
            if (!clean)
                continue;
            const matchIndex = existing.findIndex(item => item && item.name === clean.name);
            if (matchIndex >= 0)
                existing[matchIndex] = clean;
            else
                existing.push(clean);
            lastEntry = clean;
            count++;
        }

        if (count === 0) {
            appearancePage.statusError = true;
            appearancePage.statusMessage = "No valid preset found in JSON.";
            return false;
        }

        Settings.appearancePresets = existing;
        if (count === 1 && lastEntry)
            appearancePage.applyPreset(lastEntry);

        appearancePage.statusError = false;
        appearancePage.statusMessage = count === 1 ? "Imported and applied preset \"" + lastEntry.name + "\"." : "Imported " + count + " presets.";
        return true;
    }

    function buildExportJson(): string {
        const custom = Array.isArray(Settings.appearancePresets) ? Settings.appearancePresets : [];
        if (custom.length > 0)
            return JSON.stringify(custom, null, 2);
        const currentName = presetNameField.text.trim() !== "" ? presetNameField.text.trim() : "Custom";
        return JSON.stringify([appearancePage.currentSnapshot(currentName)], null, 2);
    }

    function openExport(payload: string, label: string): void {
        appearancePage.browsingFile = false;
        appearancePage.transferMode = "export";
        appearancePage.transferOpen = true;
        appearancePage.transferText = payload;
        appearancePage.statusError = false;
        appearancePage.statusMessage = "";
        clipboardCopy.command = ["sh", "-c", "command -v wl-copy >/dev/null 2>&1 && printf '%s' \"$1\" | wl-copy || true", "qsbar-export", payload];
        clipboardCopy.running = true;
        appearancePage.statusMessage = label + " ready (copied to clipboard).";
    }

    function openImport(): void {
        if (appearancePage.transferOpen && appearancePage.transferMode === "import") {
            appearancePage.transferOpen = false;
            appearancePage.browsingFile = false;
            return;
        }
        appearancePage.browsingFile = false;
        appearancePage.transferMode = "import";
        appearancePage.transferOpen = true;
        appearancePage.transferText = "";
        appearancePage.statusError = false;
        appearancePage.statusMessage = "";
    }

    Process {
        id: clipboardCopy
    }

    Process {
        id: clipboardPaste

        stdout: StdioCollector {
            id: pastedStdout
        }

        onExited: exitCode => {
            if (exitCode !== 0 || pastedStdout.text.trim() === "") {
                appearancePage.statusError = true;
                appearancePage.statusMessage = "Clipboard is empty or wl-paste is unavailable.";
                return;
            }
            appearancePage.transferText = pastedStdout.text.trim();
            appearancePage.importFromJson(appearancePage.transferText);
        }
    }

    Process {
        id: fileExporter

        stderr: StdioCollector {
            id: exportStderr
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                appearancePage.statusError = true;
                appearancePage.statusMessage = exportStderr.text.trim().split("\n")[0] || "Could not write preset file.";
                return;
            }
            appearancePage.statusError = false;
            appearancePage.statusMessage = "Saved presets to " + appearancePage.transferPath;
        }
    }

    Process {
        id: fileImporter

        stdout: StdioCollector {
            id: importStdout
        }

        stderr: StdioCollector {
            id: importStderr
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                appearancePage.statusError = true;
                appearancePage.statusMessage = importStderr.text.trim().split("\n")[0] || "Could not read preset file.";
                return;
            }
            appearancePage.transferText = importStdout.text.trim();
            appearancePage.importFromJson(appearancePage.transferText);
        }
    }

    Group {
        title: "Presets"

        Column {
            id: presetList

            readonly property bool hit: SettingsContext.shows(presetList, "presets default dark glass red high contrast rounded amethyst emerald frost")

            width: parent.width
            spacing: 6
            visible: presetList.hit

            Repeater {
                model: appearancePage.builtinPresets

                delegate: Item {
                    id: builtinRow

                    required property var modelData

                    width: presetList.width
                    height: 30

                    IconText {
                        id: builtinSwatch

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        fillBarHeight: false
                        text: Glyphs.palette
                        color: builtinRow.modelData.accentColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        anchors.left: builtinSwatch.right
                        anchors.leftMargin: 10
                        anchors.right: builtinApply.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        text: builtinRow.modelData.name
                        color: Theme.textPrimary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    PanelButton {
                        id: builtinApply

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Apply"
                        onActivated: appearancePage.applyPreset(builtinRow.modelData)
                    }
                }
            }

            Repeater {
                model: Array.isArray(Settings.appearancePresets) ? Settings.appearancePresets : []

                delegate: Item {
                    id: customRow

                    required property var modelData
                    required property int index

                    width: presetList.width
                    height: 30

                    IconText {
                        id: customSwatch

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        fillBarHeight: false
                        text: Glyphs.palette
                        color: customRow.modelData.accentColor || Theme.accent
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Text {
                        anchors.left: customSwatch.right
                        anchors.leftMargin: 10
                        anchors.right: customApply.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        text: customRow.modelData.name || "Custom"
                        color: Theme.textPrimary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }

                    PanelButton {
                        id: customApply

                        anchors.right: customExport.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Apply"
                        onActivated: appearancePage.applyPreset(customRow.modelData)
                    }

                    PanelButton {
                        id: customExport

                        anchors.right: customDelete.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Export"
                        onActivated: appearancePage.openExport(JSON.stringify(customRow.modelData, null, 2), "Preset \"" + (customRow.modelData.name || "Custom") + "\"")
                    }

                    PanelButton {
                        id: customDelete

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: Glyphs.xmark
                        implicitWidth: 26
                        onActivated: appearancePage.deletePreset(customRow.index)
                    }
                }
            }
        }

        Item {
            id: savePresetRow

            readonly property bool hit: SettingsContext.shows(savePresetRow, "save current preset")

            width: parent.width
            height: 32
            visible: savePresetRow.hit

            TextField {
                id: presetNameField

                anchors.left: parent.left
                anchors.right: savePresetButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                placeholder: "Preset name"
                onAccepted: {
                    if (presetNameField.text.trim() !== "") {
                        appearancePage.savePreset(presetNameField.text);
                        presetNameField.clear();
                    }
                }
            }

            PanelButton {
                id: savePresetButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 30
                label: "Save current"
                accented: true
                available: presetNameField.text.trim() !== ""
                onActivated: {
                    appearancePage.savePreset(presetNameField.text);
                    presetNameField.clear();
                }
            }
        }

        Column {
            id: transferSection

            readonly property bool hit: SettingsContext.shows(transferSection, "import export presets json file clipboard share")

            width: parent.width
            spacing: 8
            visible: transferSection.hit

            Item {
                width: parent.width
                height: 30

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    PanelButton {
                        height: 28
                        label: "Import"
                        accented: appearancePage.transferOpen && appearancePage.transferMode === "import"
                        onActivated: appearancePage.openImport()
                    }

                    PanelButton {
                        height: 28
                        label: Array.isArray(Settings.appearancePresets) && Settings.appearancePresets.length > 0 ? "Export custom" : "Export current"
                        accented: appearancePage.transferOpen && appearancePage.transferMode === "export"
                        onActivated: {
                            if (appearancePage.transferOpen && appearancePage.transferMode === "export") {
                                appearancePage.transferOpen = false;
                                appearancePage.browsingFile = false;
                                return;
                            }
                            const hasCustom = Array.isArray(Settings.appearancePresets) && Settings.appearancePresets.length > 0;
                            appearancePage.openExport(appearancePage.buildExportJson(), hasCustom ? "Custom presets" : "Current preset");
                        }
                    }
                }

                PanelButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: appearancePage.transferOpen
                    glyph: Glyphs.xmark
                    implicitWidth: 26
                    implicitHeight: 26
                    onActivated: {
                        appearancePage.transferOpen = false;
                        appearancePage.browsingFile = false;
                        appearancePage.statusMessage = "";
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: appearancePage.transferOpen

                Item {
                    width: parent.width
                    height: 30

                    TextField {
                        id: jsonPayloadField

                        anchors.left: parent.left
                        anchors.right: appearancePage.transferMode === "import" ? payloadActionButton.left : clipboardButton.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        placeholder: appearancePage.transferMode === "import" ? "Paste preset JSON here" : "Preset JSON"
                        text: appearancePage.transferText
                        onTextChanged: {
                            if (appearancePage.transferText !== jsonPayloadField.text)
                                appearancePage.transferText = jsonPayloadField.text;
                        }
                        onAccepted: {
                            if (appearancePage.transferMode === "import" && jsonPayloadField.text.trim() !== "")
                                appearancePage.importFromJson(jsonPayloadField.text);
                        }
                    }

                    PanelButton {
                        id: payloadActionButton

                        anchors.right: clipboardButton.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        visible: appearancePage.transferMode === "import"
                        label: "Apply JSON"
                        accented: true
                        available: jsonPayloadField.text.trim() !== ""
                        onActivated: appearancePage.importFromJson(jsonPayloadField.text)
                    }

                    PanelButton {
                        id: clipboardButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        label: appearancePage.transferMode === "import" ? "From clipboard" : "Copy"
                        onActivated: {
                            if (appearancePage.transferMode === "import") {
                                clipboardPaste.command = ["sh", "-c", "wl-paste --no-newline 2>/dev/null || wl-paste 2>/dev/null"];
                                clipboardPaste.running = true;
                            } else {
                                clipboardCopy.command = ["sh", "-c", "command -v wl-copy >/dev/null 2>&1 && printf '%s' \"$1\" | wl-copy", "qsbar-copy", jsonPayloadField.text];
                                clipboardCopy.running = true;
                                appearancePage.statusError = false;
                                appearancePage.statusMessage = "Copied JSON to clipboard.";
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 30

                    TextField {
                        id: presetPathField

                        anchors.left: parent.left
                        anchors.right: browsePresetButton.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        placeholder: "~/qsbar-presets.json"
                        text: appearancePage.transferPath
                        onTextChanged: {
                            if (appearancePage.transferPath !== presetPathField.text)
                                appearancePage.transferPath = presetPathField.text;
                        }
                    }

                    PanelButton {
                        id: browsePresetButton

                        anchors.right: fileActionButton.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        glyph: appearancePage.browsingFile ? Glyphs.xmark : Glyphs.folderOpen
                        onActivated: appearancePage.browsingFile = !appearancePage.browsingFile
                    }

                    PanelButton {
                        id: fileActionButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 30
                        label: appearancePage.transferMode === "import" ? "Load file" : "Save file"
                        accented: appearancePage.transferMode === "export"
                        available: presetPathField.text.trim() !== ""
                        onActivated: {
                            const rawPath = presetPathField.text.trim();
                            if (rawPath === "")
                                return;
                            appearancePage.transferPath = rawPath;
                            if (appearancePage.transferMode === "import") {
                                fileImporter.command = ["sh", "-c", "p=\"$1\"; case \"$p\" in \"~/\"*) p=\"$HOME/${p#~/}\" ;; esac; cat -- \"$p\"", "qsbar-import", rawPath];
                                fileImporter.running = true;
                            } else {
                                const content = jsonPayloadField.text.trim() !== "" ? jsonPayloadField.text : appearancePage.buildExportJson();
                                fileExporter.command = ["sh", "-c", "p=\"$1\"; case \"$p\" in \"~/\"*) p=\"$HOME/${p#~/}\" ;; esac; mkdir -p -- \"$(dirname -- \"$p\")\" && printf '%s\\n' \"$2\" > \"$p\"", "qsbar-export", rawPath, content];
                                fileExporter.running = true;
                            }
                        }
                    }
                }

                Loader {
                    width: parent.width
                    active: appearancePage.browsingFile
                    visible: active

                    sourceComponent: FileBrowser {
                        folders: appearancePage.transferMode === "export"
                        nameFilters: ["*.json"]
                        fileGlyph: Glyphs.palette
                        emptyFilesText: "No .json files or folders in here."
                        start: appearancePage.transferPath
                        onChosen: path => {
                            appearancePage.browsingFile = false;
                            if (appearancePage.transferMode === "export") {
                                appearancePage.transferPath = (path.endsWith("/") ? path : path + "/") + "qsbar-presets.json";
                            } else {
                                appearancePage.transferPath = path;
                                fileImporter.command = ["sh", "-c", "p=\"$1\"; case \"$p\" in \"~/\"*) p=\"$HOME/${p#~/}\" ;; esac; cat -- \"$p\"", "qsbar-import", path];
                                fileImporter.running = true;
                            }
                        }
                    }
                }
            }

            PanelMessage {
                width: parent.width
                visible: appearancePage.statusMessage !== ""
                warning: appearancePage.statusError
                text: appearancePage.statusMessage
            }
        }
    }

    Group {
        title: "Accent and hover"

        SwatchRow {
            label: "Accent colour"
            options: SettingsContext.accentColors
            current: Settings.accentColor
            onPicked: value => Settings.accentColor = value
        }

        SliderRow {
            label: "Hover opacity"
            value: Settings.hoverOpacity
            minimum: 0
            maximum: 0.6
            decimals: 2
            onAdjusted: newValue => Settings.hoverOpacity = newValue
        }

        SliderRow {
            label: "Hover corner radius"
            value: Settings.hoverRadius
            minimum: 0
            maximum: 20
            suffix: "px"
            onAdjusted: newValue => Settings.hoverRadius = Math.round(newValue)
        }
    }

    Group {
        title: "Panels"

        SwatchRow {
            label: "Surface colour"
            options: SettingsContext.surfaceColors
            current: Settings.surfaceColor
            onPicked: value => Settings.surfaceColor = value
        }

        SliderRow {
            label: "Opacity"
            value: Settings.panelOpacity
            minimum: 0.3
            maximum: 1
            decimals: 2
            onAdjusted: newValue => Settings.panelOpacity = newValue
        }

        SliderRow {
            label: "Corner radius"
            value: Settings.panelRadius
            minimum: 0
            maximum: 24
            suffix: "px"
            onAdjusted: newValue => Settings.panelRadius = Math.round(newValue)
        }

        ToggleRow {
            label: "Background blur"
            checked: Settings.panelBlur
            onToggled: Settings.panelBlur = !Settings.panelBlur
        }

        ButtonRow {
            label: "Match bar colour and opacity"
            enabledAction: Settings.surfaceColor !== Settings.barColor || Settings.panelOpacity !== Settings.barOpacity
            onTriggered: {
                Settings.surfaceColor = Settings.barColor;
                Settings.panelOpacity = Settings.barOpacity;
            }
        }
    }

    Group {
        title: "Icons"

        SliderRow {
            label: "Icon size"
            value: Settings.iconSize
            minimum: 10
            maximum: 24
            suffix: "px"
            onAdjusted: newValue => Settings.iconSize = Math.round(newValue)
        }

        SliderRow {
            label: "Icon padding"
            value: Settings.iconPadding
            minimum: 0
            maximum: 12
            suffix: "px"
            onAdjusted: newValue => Settings.iconPadding = Math.round(newValue)
        }

        SliderRow {
            label: "Module spacing"
            value: Settings.moduleSpacing
            minimum: 0
            maximum: 16
            suffix: "px"
            onAdjusted: newValue => Settings.moduleSpacing = Math.round(newValue)
        }

        SliderRow {
            label: "Workspace spacing"
            value: Settings.workspaceSpacing
            minimum: 2
            maximum: 28
            suffix: "px"
            onAdjusted: newValue => Settings.workspaceSpacing = Math.round(newValue)
        }
    }
}
