pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
    id: pageRoot

    property int newDelay: 0
    property bool newMinimized: false
    property string pickerQuery: ""

    readonly property var filteredApps: {
        const q = pageRoot.pickerQuery.trim().toLowerCase();
        const all = StartupApps.installedApps;
        if (q === "")
            return all;
        const out = [];
        for (let i = 0; i < all.length; i++) {
            const app = all[i];
            if (app.name.toLowerCase().indexOf(q) !== -1 || app.command.toLowerCase().indexOf(q) !== -1 || app.comment.toLowerCase().indexOf(q) !== -1)
                out.push(app);
        }
        return out;
    }

    spacing: 18

    PanelMessage {
        width: parent.width
        visible: StartupApps.lastError !== "" && !SettingsContext.searching
        warning: true
        text: StartupApps.lastError
    }

    Group {
        title: "Applications"

        PanelMessage {
            width: parent.width
            visible: StartupApps.entries.length === 0 && !SettingsContext.searching
            text: "No startup applications configured yet."
        }

        Repeater {
            model: StartupApps.entries

            delegate: Item {
                id: entryRow

                required property var modelData
                required property int index

                readonly property bool hit: SettingsContext.shows(entryRow, entryRow.modelData.name + " " + entryRow.modelData.command)

                readonly property string metaText: {
                    const tags = [];
                    if (entryRow.modelData.delay > 0)
                        tags.push(entryRow.modelData.delay + "s delay");
                    if (entryRow.modelData.minimized)
                        tags.push("minimized");
                    return tags.length > 0 ? entryRow.modelData.command + "  (" + tags.join(" · ") + ")" : entryRow.modelData.command;
                }

                width: parent.width
                height: entryRow.hit ? 46 : 0
                visible: entryRow.hit

                Row {
                    anchors.left: parent.left
                    anchors.right: controls.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Enabled toggle switch
                    Rectangle {
                        id: switchTrack

                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 18
                        radius: Theme.pill(18)
                        color: entryRow.modelData.enabled ? Theme.accent : Theme.fillTrack

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durationFast
                            }
                        }

                        Rectangle {
                            width: 14
                            height: 14
                            radius: Theme.pill(14)
                            anchors.verticalCenter: parent.verticalCenter
                            x: entryRow.modelData.enabled ? parent.width - width - 2 : 2
                            color: Theme.textPrimary

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: StartupApps.toggle(entryRow.index)
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - switchTrack.width - 10
                        spacing: 2

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: entryRow.modelData.name
                            color: entryRow.modelData.enabled ? Theme.textPrimary : Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeightStrong
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            textFormat: Text.PlainText
                            text: entryRow.metaText
                            color: Theme.textMuted
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                            elide: Text.ElideRight
                        }
                    }
                }

                Row {
                    id: controls

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    PanelButton {
                        label: "Min"
                        accented: entryRow.modelData.minimized
                        onActivated: StartupApps.toggleMinimized(entryRow.index)
                    }

                    PanelButton {
                        glyph: Glyphs.play
                        onActivated: StartupApps.launchNow(entryRow.modelData.command, entryRow.modelData.minimized)
                    }

                    PanelButton {
                        glyph: Glyphs.xmark
                        onActivated: StartupApps.remove(entryRow.index)
                    }
                }
            }
        }
    }

    Group {
        title: "App picker"

        Item {
            id: pickerBlock

            readonly property bool hit: SettingsContext.shows(pickerBlock, "App picker installed applications search browse")

            width: parent.width
            height: pickerBlock.hit ? pickerColumn.implicitHeight : 0
            visible: pickerBlock.hit

            Column {
                id: pickerColumn

                width: parent.width
                spacing: 8

                TextField {
                    id: pickerSearch

                    width: parent.width
                    placeholder: "Search installed apps (click to fill, + to add)..."
                    onTextChanged: pageRoot.pickerQuery = text
                }

                PanelMessage {
                    width: parent.width
                    visible: pageRoot.filteredApps.length === 0
                    text: StartupApps.installedApps.length === 0 ? "No desktop applications found." : "No apps match “" + pageRoot.pickerQuery.trim() + "”."
                }

                ListView {
                    id: appList

                    width: parent.width
                    height: Math.min(contentHeight, 220)
                    visible: pageRoot.filteredApps.length > 0
                    clip: true
                    spacing: 4
                    model: pageRoot.filteredApps

                    delegate: Rectangle {
                        id: appRow

                        required property var modelData

                        width: appList.width
                        height: 40
                        radius: Theme.radius
                        color: appMouse.containsMouse ? Theme.fillHover : "transparent"

                        MouseArea {
                            id: appMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                nameInput.text = appRow.modelData.name;
                                cmdInput.text = appRow.modelData.command;
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: quickAdd.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                width: parent.width
                                textFormat: Text.PlainText
                                text: appRow.modelData.name
                                color: Theme.textPrimary
                                font.family: Theme.sansFamily
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightStrong
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                textFormat: Text.PlainText
                                text: appRow.modelData.command
                                color: Theme.textMuted
                                font.family: Theme.monoFamily
                                font.pixelSize: Theme.fontSizeSmall - 1
                                elide: Text.ElideRight
                            }
                        }

                        PanelButton {
                            id: quickAdd

                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: Glyphs.plus
                            onActivated: StartupApps.add(appRow.modelData.name, appRow.modelData.command, pageRoot.newDelay, pageRoot.newMinimized)
                        }
                    }
                }
            }
        }
    }

    Group {
        title: "Add startup application"

        Item {
            id: addForm

            readonly property bool hit: SettingsContext.shows(addForm, "Add startup application command delay minimized background")

            width: parent.width
            height: addForm.hit ? formColumn.implicitHeight : 0
            visible: addForm.hit

            Column {
                id: formColumn

                width: parent.width
                spacing: 10

                TextField {
                    id: nameInput

                    width: parent.width
                    label: "Name"
                    placeholder: "e.g. qBittorrent"
                }

                TextField {
                    id: cmdInput

                    width: parent.width
                    label: "Command"
                    placeholder: "e.g. flatpak run org.qbittorrent.qBittorrent"
                    onAccepted: addButton.activated()
                }

                StepperRow {
                    label: "Start delay (seconds)"
                    value: pageRoot.newDelay
                    minimum: 0
                    maximum: 60
                    step: 1
                    onAdjusted: newValue => pageRoot.newDelay = Math.round(newValue)
                }

                ToggleRow {
                    label: "Start minimized (background scratchpad, SUPER + S)"
                    checked: pageRoot.newMinimized
                    onToggled: pageRoot.newMinimized = !pageRoot.newMinimized
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    PanelButton {
                        id: addButton

                        label: "Add"
                        accented: true
                        available: cmdInput.text.trim() !== ""
                        onActivated: {
                            if (StartupApps.add(nameInput.text, cmdInput.text, pageRoot.newDelay, pageRoot.newMinimized)) {
                                nameInput.clear();
                                cmdInput.clear();
                                pageRoot.newDelay = 0;
                                pageRoot.newMinimized = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
