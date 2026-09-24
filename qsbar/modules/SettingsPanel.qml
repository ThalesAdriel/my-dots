pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

// One page of the settings window, picked by `page`, or with a `query` every page at once filtered down to the rows that match. Only what is on screen is built: the display canvas and the wallpaper grid are the two heaviest trees in the shell, and neither is worth constructing while some other page is showing.
Item {
    id: root

    property string page: "appearance"

    // The search field's text. While it holds anything, every page but Displays is built, stacked under its own heading, with only the matching rows left showing, so a setting can be changed right there in the results.
    property string query: ""
    readonly property bool searching: root.query.trim() !== ""
    readonly property string needle: root.query.trim().toLowerCase()

    // The window's list of { key, title }, for the headings over each page in the results.
    property var pages: []
    readonly property var pageKeys: ["appearance", "wallpaper", "bar", "notifications", "general", "displays", "lock", "theme"]

    // A heading in the results was clicked: the window leaves the search for that page.
    signal pageRequested(string key)

    function titleOf(key: string): string {
        for (const entry of root.pages) {
            if (entry.key === key)
                return entry.title;
        }
        return key;
    }

    // Whether a row stays up for the current query: it matches on its own label, or on the title of the group or page it sits in, so "blur" finds both blur toggles and "lock screen" finds the whole page. Walked up through `searchTitle` rather than handed down, since the rows are declared long before they know where they will sit.
    function shows(item: Item, label: string): bool {
        if (!root.searching)
            return true;
        let text = label;
        for (let node = item.parent; node; node = node.parent) {
            if (node.searchTitle !== undefined)
                text += " " + node.searchTitle;
        }
        return text.toLowerCase().indexOf(root.needle) !== -1;
    }

    // Whether anything among these children is a row that matched. Read off each row's own `hit` rather than off what is visible: a hidden group hides its rows too, and counting visible children would keep a group hidden for good once it had been.
    function anyHit(children: var): bool {
        for (let index = 0; index < children.length; index++) {
            if (children[index].hit === true)
                return true;
        }
        return false;
    }

    // The neutrals, then two purples and two pinks, all dark enough for the bar's white text to stay readable at full opacity.
    readonly property var barColors: ["#11121a", "#000000", "#1b1b1b", "#202020", "#2e3436", "#3d3846", "#613583", "#813d9c", "#9c1d5e", "#c2407a"]
    readonly property var surfaceColors: ["#0d0d12", "#000000", "#141414", "#1a1a22", "#1c2226", "#241f31"]
    // The last two are libadwaita's purple and pink accents, bright enough to read as an accent and still dark enough for the white text drawn on top of it.
    readonly property var accentColors: ["#3584e4", "#2ec27e", "#f5c211", "#ff7800", "#e01b24", "#986a44", "#9141ac", "#d56199"]

    // What the picture fields list when browsing: what Qt, with qt6-imageformats, can draw.
    readonly property var imageFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]

    implicitHeight: pageStack.implicitHeight

    // A titled card holding one group of settings; everything used to run down the panel as one flat list with hairlines, which read as a wall of rows rather than five separate things.
    component Group: Column {
        id: group

        property string title: ""
        default property alias rows: groupRows.data

        readonly property string searchTitle: group.title
        readonly property bool hit: root.searching && root.anyHit(groupRows.children)

        width: parent.width
        spacing: 8
        visible: !root.searching || group.hit

        // Through `data` rather than as plain children: the default property is aliased to the card's column, so anything declared loose here would land inside the card with the settings rows.
        data: [
            Text {
                text: group.title
                color: Theme.textMuted
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightStrong
                font.capitalization: Font.AllUppercase
            },

            Rectangle {
                width: group.width
                height: groupRows.implicitHeight + 24

                radius: Theme.cardRadius
                color: Theme.settingsCard

                Column {
                    id: groupRows

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12

                    spacing: 6
                }
            }
        ]
    }

    component RowLabel: Text {
        color: Theme.textSecondary
        font.family: Theme.sansFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    component SliderRow: Item {
        id: sliderRow

        property string label: ""
        property real value: 0
        property real minimum: 0
        property real maximum: 1
        property int decimals: 0
        property string suffix: ""

        // What the number on the right reads; overridden where one end of the range means something other than its number.
        property string valueText: sliderRow.value.toFixed(sliderRow.decimals) + sliderRow.suffix

        // Set false where the row only means something some of the time, rather than overriding `visible`, which would take it out of the search.
        property bool applies: true
        readonly property bool hit: sliderRow.applies && root.shows(sliderRow, sliderRow.label)

        signal adjusted(real newValue)

        width: parent.width
        height: 42
        visible: sliderRow.hit

        RowLabel {
            anchors.left: parent.left
            anchors.top: parent.top
            text: sliderRow.label
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: sliderRow.valueText
            color: Theme.textPrimary
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        LevelSlider {
            id: slider

            // A twentieth of the range a press, and never less than one whole step where the setting is a whole number: a fraction would round straight back to where it started.
            readonly property real keyStep: Math.max((sliderRow.maximum - sliderRow.minimum) / 20, sliderRow.decimals === 0 ? 1 : 0)

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            maximum: 1
            value: sliderRow.maximum > sliderRow.minimum ? (sliderRow.value - sliderRow.minimum) / (sliderRow.maximum - sliderRow.minimum) : 0

            onMoved: newValue => sliderRow.adjusted(sliderRow.minimum + newValue * (sliderRow.maximum - sliderRow.minimum))

            activeFocusOnTab: true
            Keys.onLeftPressed: sliderRow.adjusted(Math.max(sliderRow.value - slider.keyStep, sliderRow.minimum))
            Keys.onRightPressed: sliderRow.adjusted(Math.min(sliderRow.value + slider.keyStep, sliderRow.maximum))

            FocusRing {}
        }
    }

    component SwatchRow: Item {
        id: swatchRow

        property string label: ""
        property var options: []
        property string current: ""

        property bool applies: true
        readonly property bool hit: swatchRow.applies && root.shows(swatchRow, swatchRow.label)

        signal picked(string value)

        width: parent.width
        height: 34
        visible: swatchRow.hit

        RowLabel {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: swatchRow.label
        }

        // One Tab stop for the row, like a set of radio buttons, with the arrows walking the choice.
        FocusRing {
            target: swatches
        }

        Row {
            id: swatches

            function step(delta: int): void {
                const index = swatchRow.options.indexOf(swatchRow.current);
                const next = Math.min(Math.max(index < 0 ? 0 : index + delta, 0), swatchRow.options.length - 1);
                swatchRow.picked(swatchRow.options[next]);
            }

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            activeFocusOnTab: true
            Keys.onLeftPressed: swatches.step(-1)
            Keys.onRightPressed: swatches.step(1)

            Repeater {
                model: swatchRow.options

                delegate: Rectangle {
                    id: swatch

                    required property string modelData

                    width: 22
                    height: 22
                    radius: Theme.radius
                    color: swatch.modelData
                    border.width: swatchRow.current === swatch.modelData ? 2 : 1
                    border.color: swatchRow.current === swatch.modelData ? Theme.textPrimary : Theme.cardBorder

                    MouseArea {
                        anchors.fill: parent
                        onClicked: swatchRow.picked(swatch.modelData)
                    }
                }
            }
        }
    }

    component ToggleRow: Item {
        id: toggleRow

        property string label: ""
        property bool checked: false

        property bool applies: true
        readonly property bool hit: toggleRow.applies && root.shows(toggleRow, toggleRow.label)

        signal toggled

        width: parent.width
        height: 34
        visible: toggleRow.hit

        RowLabel {
            anchors.left: parent.left
            anchors.right: toggle.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: toggleRow.label
        }

        Rectangle {
            id: toggle

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: 44
            height: 24
            radius: Theme.pill(24)
            color: toggleRow.checked ? Theme.accent : Theme.fillTrack

            activeFocusOnTab: true
            Keys.onSpacePressed: toggleRow.toggled()
            Keys.onReturnPressed: toggleRow.toggled()
            Keys.onEnterPressed: toggleRow.toggled()

            FocusRing {
                radius: Theme.pill(30)
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationBase
                }
            }

            Rectangle {
                width: 18
                height: 18
                radius: Theme.pill(18)
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
                x: toggleRow.checked ? parent.width - width - 3 : 3

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.durationBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easingCurve
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: toggleRow.toggled()
            }
        }
    }

    component ButtonRow: Rectangle {
        id: buttonRow

        property string label: ""
        property bool enabledAction: true

        property bool applies: true
        readonly property bool hit: buttonRow.applies && root.shows(buttonRow, buttonRow.label)

        signal triggered

        function press(): void {
            if (buttonRow.enabledAction)
                buttonRow.triggered();
        }

        width: parent.width
        height: 34
        visible: buttonRow.hit
        radius: Theme.radius
        opacity: buttonRow.enabledAction ? 1 : 0.45

        activeFocusOnTab: buttonRow.enabledAction
        Keys.onSpacePressed: buttonRow.press()
        Keys.onReturnPressed: buttonRow.press()
        Keys.onEnterPressed: buttonRow.press()

        FocusRing {}
        color: {
            if (!buttonRow.enabledAction)
                return Theme.fillTrack;
            if (buttonMouse.containsPress)
                return Theme.fillPressed;
            return buttonMouse.containsMouse ? Theme.fillHover : Theme.fillTrack;
        }

        Text {
            anchors.centerIn: parent
            text: buttonRow.label
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightNormal
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: buttonRow.enabledAction
            onClicked: buttonRow.triggered()
        }
    }

    // A handful of named values side by side, the chosen one lit: the same pills the display scale is picked with. `options` is [{ value, label }].
    component ChoiceRow: Item {
        id: choiceRow

        property string label: ""
        property var options: []
        property var current

        property bool applies: true
        readonly property bool hit: choiceRow.applies && root.shows(choiceRow, choiceRow.label)

        signal picked(var value)

        width: parent.width
        height: 34
        visible: choiceRow.hit

        RowLabel {
            anchors.left: parent.left
            anchors.right: choices.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: choiceRow.label
        }

        FocusRing {
            target: choices
        }

        Row {
            id: choices

            function step(delta: int): void {
                let index = -1;
                for (let at = 0; at < choiceRow.options.length; at++) {
                    if (choiceRow.options[at].value === choiceRow.current)
                        index = at;
                }
                const next = Math.min(Math.max(index < 0 ? 0 : index + delta, 0), choiceRow.options.length - 1);
                choiceRow.picked(choiceRow.options[next].value);
            }

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            activeFocusOnTab: true
            Keys.onLeftPressed: choices.step(-1)
            Keys.onRightPressed: choices.step(1)

            Repeater {
                model: choiceRow.options

                delegate: Rectangle {
                    id: choice

                    required property var modelData

                    readonly property bool chosen: choiceRow.current === choice.modelData.value

                    width: choiceLabel.implicitWidth + 20
                    height: 24
                    radius: Theme.radius
                    color: {
                        if (choiceMouse.containsPress)
                            return Theme.fillPressed;
                        if (choiceMouse.containsMouse)
                            return Theme.fillHover;
                        return choice.chosen ? Theme.accent : Theme.fillTrack;
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durationFast
                        }
                    }

                    Text {
                        id: choiceLabel
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: choice.modelData.label
                        color: choice.chosen ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightNormal
                    }

                    MouseArea {
                        id: choiceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: choiceRow.picked(choice.modelData.value)
                    }
                }
            }
        }
    }

    // A line of text that saves itself when Enter is pressed or the focus leaves it, and then goes back to showing the setting, so a value the handler turned down does not sit there looking saved. With `browse` set to "file" or "folder", a button beside it opens a browser under the row, for picking a path rather than typing one out.
    component FieldRow: Column {
        id: fieldRow

        property string label: ""
        property string value: ""
        property string placeholder: ""
        property string browse: ""
        property var nameFilters: []
        property bool browsing: false

        property bool applies: true
        readonly property bool hit: fieldRow.applies && root.shows(fieldRow, fieldRow.label)

        signal committed(string text)

        width: parent.width
        spacing: 4
        visible: fieldRow.hit

        Item {
            width: parent.width
            height: 34

            RowLabel {
                anchors.left: parent.left
                anchors.right: field.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: fieldRow.label
            }

            TextField {
                id: field

                anchors.right: browseButton.visible ? browseButton.left : parent.right
                anchors.rightMargin: browseButton.visible ? 6 : 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(300, fieldRow.width * 0.62) - (browseButton.visible ? browseButton.width + 6 : 0)

                text: fieldRow.value
                placeholder: fieldRow.placeholder

                onEditingFinished: {
                    if (field.text !== fieldRow.value)
                        fieldRow.committed(field.text);
                    field.text = Qt.binding(() => fieldRow.value);
                }
            }

            PanelButton {
                id: browseButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                visible: fieldRow.browse !== ""
                implicitWidth: 30
                implicitHeight: 30
                glyph: fieldRow.browsing ? Glyphs.xmark : Glyphs.folderOpen
                onActivated: fieldRow.browsing = !fieldRow.browsing
            }
        }

        // Built when opened and let go when closed: a folder listing is watched on disk for as long as it exists.
        Loader {
            width: parent.width
            active: fieldRow.browsing
            visible: active

            sourceComponent: FileBrowser {
                folders: fieldRow.browse === "folder"
                nameFilters: fieldRow.nameFilters
                start: fieldRow.value
                onChosen: path => {
                    fieldRow.browsing = false;
                    fieldRow.committed(path);
                }
            }
        }
    }

    // A folder's contents, walked by clicking, under a FieldRow. Drawn in the shell rather than handed to the portal's file chooser: that is an ordinary window, which opens underneath the overlay settings sits on and takes the focus it holds, closing settings on its way in.
    component FileBrowser: Rectangle {
        id: browser

        // Picking a folder rather than a file: only folders are listed, and the button in the header takes the one on show.
        property bool folders: false
        property var nameFilters: []

        // The field's value. A folder field opens on it, a file field on the folder the file is in, and anything that is not a path opens at home.
        property string start: ""

        readonly property string home: Quickshell.env("HOME") || "/"

        // The folder on show, kept here and handed to the model rather than read back out of it: the model's own folder does not notify a binding when it moves, so a path derived from it stayed empty.
        property string current: ""

        signal chosen(string path)

        // Home written as ~, the way the fields are filled in by hand; quicklock and the wallpaper service both read it back.
        function tilde(path: string): string {
            return path === browser.home || path.startsWith(browser.home + "/") ? "~" + path.slice(browser.home.length) : path;
        }

        function open(path: string): void {
            browser.current = path;
        }

        function parentOf(path: string): string {
            return path.slice(0, Math.max(path.lastIndexOf("/"), 1));
        }

        implicitHeight: browserHeader.height + (browserList.count > 0 ? browserList.height : emptyNote.implicitHeight) + 26
        radius: Theme.radius
        color: Theme.fillTrack

        Component.onCompleted: {
            const path = browser.start.startsWith("~/") ? browser.home + browser.start.slice(1) : browser.start;
            if (!path.startsWith("/"))
                browser.open(browser.home);
            else
                browser.open(browser.folders ? path : browser.parentOf(path));
        }

        FolderListModel {
            id: folderModel

            folder: browser.current !== "" ? "file://" + browser.current.split("/").map(encodeURIComponent).join("/") : ""
            showDirsFirst: true
            showDotAndDotDot: false
            showFiles: !browser.folders
            nameFilters: browser.nameFilters
            caseSensitive: false
            sortCaseSensitive: false
        }

        Item {
            id: browserHeader

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            height: 26

            PanelButton {
                id: upButton

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                glyph: Glyphs.arrowUp
                available: browser.current !== "/"
                onActivated: browser.open(browser.parentOf(browser.current))
            }

            Text {
                anchors.left: upButton.right
                anchors.right: chooseButton.visible ? chooseButton.left : parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter

                textFormat: Text.PlainText
                text: browser.tilde(browser.current)
                color: Theme.textSecondary
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideMiddle
            }

            PanelButton {
                id: chooseButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                visible: browser.folders
                label: "Use this folder"
                accented: true
                available: browser.current !== ""
                onActivated: browser.chosen(browser.tilde(browser.current))
            }
        }

        ListView {
            id: browserList

            anchors.top: browserHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 6
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            height: Math.min(browserList.count, 8) * 26
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: folderModel

            // The arrows move through the list on their own, ListView does that; Enter takes what they landed on and Backspace goes up a level.
            function take(item: var): void {
                if (!item)
                    return;
                if (item.fileIsDir)
                    browser.open(item.filePath);
                else
                    browser.chosen(browser.tilde(item.filePath));
            }

            activeFocusOnTab: browserList.count > 0
            onActiveFocusChanged: {
                if (browserList.activeFocus && browserList.currentIndex < 0)
                    browserList.currentIndex = 0;
            }
            Keys.onReturnPressed: browserList.take(browserList.currentItem)
            Keys.onEnterPressed: browserList.take(browserList.currentItem)
            Keys.onSpacePressed: browserList.take(browserList.currentItem)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Backspace && browser.current !== "/") {
                    browser.open(browser.parentOf(browser.current));
                    event.accepted = true;
                }
            }

            delegate: Rectangle {
                id: entry

                required property string fileName
                required property string filePath
                required property bool fileIsDir

                readonly property bool cursorHere: browserList.activeFocus && entry.ListView.isCurrentItem

                width: browserList.width
                height: 24
                radius: Theme.radius
                color: entryMouse.containsPress ? Theme.fillPressed : entryMouse.containsMouse || entry.cursorHere ? Theme.fillHover : "transparent"
                border.width: entry.cursorHere ? 1 : 0
                border.color: Theme.accent

                IconText {
                    id: entryIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter

                    fillBarHeight: false
                    width: 18
                    text: entry.fileIsDir ? Glyphs.folder : Glyphs.image
                    color: entry.fileIsDir ? Theme.accent : Theme.textMuted
                    font.pixelSize: 10
                }

                Text {
                    anchors.left: entryIcon.right
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    textFormat: Text.PlainText
                    text: entry.fileName
                    color: Theme.textPrimary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: entryMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: browserList.take(entry)
                }
            }
        }

        PanelMessage {
            id: emptyNote

            anchors.top: browserHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            visible: browserList.count === 0
            text: browser.folders ? "No folders in here." : "No pictures or folders in here."
        }
    }

    // A name picked out of a list too long for pills. The list opens inline under the row, like the display mode list: a popup anchored inside this window would be a second surface for a list the page can scroll.
    component PickerRow: Column {
        id: pickerRow

        property string label: ""
        property var options: []
        property string current: ""
        property bool open: false

        property bool applies: true
        readonly property bool hit: pickerRow.applies && root.shows(pickerRow, pickerRow.label)

        signal picked(string value)

        // The arrows on the closed button walk the list the way a select does, taking each one as they reach it.
        function step(delta: int): void {
            if (pickerRow.options.length === 0)
                return;
            const index = pickerRow.options.indexOf(pickerRow.current);
            const next = Math.min(Math.max(index < 0 ? 0 : index + delta, 0), pickerRow.options.length - 1);
            if (pickerRow.options[next] !== pickerRow.current)
                pickerRow.picked(pickerRow.options[next]);
        }

        width: parent.width
        spacing: 4
        visible: pickerRow.hit

        Item {
            width: parent.width
            height: 34

            RowLabel {
                anchors.left: parent.left
                anchors.right: pickerButton.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: pickerRow.label
            }

            Rectangle {
                id: pickerButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: Math.min(300, pickerRow.width * 0.62)
                height: 28
                radius: Theme.radius
                color: pickerMouse.containsPress ? Theme.fillPressed : pickerMouse.containsMouse ? Theme.fillHover : Theme.fillTrack

                activeFocusOnTab: true
                Keys.onUpPressed: pickerRow.step(-1)
                Keys.onDownPressed: pickerRow.step(1)
                Keys.onSpacePressed: pickerRow.open = !pickerRow.open
                Keys.onReturnPressed: pickerRow.open = !pickerRow.open
                Keys.onEnterPressed: pickerRow.open = !pickerRow.open

                FocusRing {}

                Text {
                    anchors.left: parent.left
                    anchors.right: pickerChevron.left
                    anchors.leftMargin: 9
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter

                    textFormat: Text.PlainText
                    text: pickerRow.current !== "" ? pickerRow.current : "Not set"
                    color: pickerRow.current !== "" ? Theme.textPrimary : Theme.textMuted
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                IconText {
                    id: pickerChevron

                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    fillBarHeight: false
                    text: pickerRow.open ? Glyphs.angleDown : Glyphs.angleRight
                    color: Theme.textMuted
                    font.pixelSize: 9
                }

                MouseArea {
                    id: pickerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: pickerRow.open = !pickerRow.open
                }
            }
        }

        ListView {
            id: pickerList

            width: parent.width
            height: Math.min(pickerList.count, 8) * 26
            visible: pickerRow.open && pickerList.count > 0

            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: pickerRow.options

            // Opened on the one already in use rather than at the top of a list that can run to dozens.
            onVisibleChanged: {
                if (pickerList.visible)
                    pickerList.positionViewAtIndex(Math.max(pickerRow.options.indexOf(pickerRow.current), 0), ListView.Center);
            }

            delegate: Rectangle {
                id: option

                required property string modelData

                readonly property bool chosen: option.modelData === pickerRow.current

                width: pickerList.width
                height: 24
                radius: Theme.radius
                color: {
                    if (optionMouse.containsPress)
                        return Theme.fillPressed;
                    if (optionMouse.containsMouse)
                        return Theme.fillHover;
                    return option.chosen ? Theme.fillTrack : "transparent";
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: optionCheck.left
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    textFormat: Text.PlainText
                    text: option.modelData
                    color: option.chosen ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.sansFamily
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                IconText {
                    id: optionCheck

                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    fillBarHeight: false
                    visible: option.chosen
                    text: Glyphs.check
                    color: Theme.accent
                    font.pixelSize: 10
                }

                MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        pickerRow.open = false;
                        if (!option.chosen)
                            pickerRow.picked(option.modelData);
                    }
                }
            }
        }
    }

    // The pictures in the wallpaper folder as tiles, the ones in use ringed. The desktop and the lock screen both pick from it and differ only in what a click does and what counts as in use.
    component WallpaperGrid: Column {
        id: grid

        property var selected: []

        signal picked(string path)

        readonly property int across: 4
        readonly property real tileWidth: Math.floor((grid.width - tiles.spacing * (grid.across - 1)) / grid.across)

        width: parent.width
        spacing: 6

        // Pictures are not settings a search can name, and building a grid of thumbnails to hide it again is the most expensive thing on either page.
        visible: !root.searching

        Flow {
            id: tiles

            // Where the arrows are, as an index into the pictures; one Tab stop for the grid, like the swatches.
            property int cursor: 0

            function move(delta: int): void {
                tiles.cursor = Math.min(Math.max(tiles.cursor + delta, 0), Wallpaper.images.length - 1);
            }

            width: parent.width
            spacing: 8
            visible: Wallpaper.images.length > 0

            activeFocusOnTab: Wallpaper.images.length > 0
            onActiveFocusChanged: {
                if (!tiles.activeFocus)
                    return;
                const at = Wallpaper.images.findIndex(path => grid.selected.indexOf(path) !== -1);
                tiles.cursor = Math.max(at, 0);
            }
            Keys.onLeftPressed: tiles.move(-1)
            Keys.onRightPressed: tiles.move(1)
            Keys.onUpPressed: tiles.move(-grid.across)
            Keys.onDownPressed: tiles.move(grid.across)
            Keys.onReturnPressed: grid.picked(Wallpaper.images[tiles.cursor])
            Keys.onEnterPressed: grid.picked(Wallpaper.images[tiles.cursor])
            Keys.onSpacePressed: grid.picked(Wallpaper.images[tiles.cursor])

            Repeater {
                model: root.searching ? [] : Wallpaper.images

                delegate: Rectangle {
                    id: tile

                    required property string modelData
                    required property int index

                    readonly property bool chosen: grid.selected.indexOf(tile.modelData) !== -1

                    width: grid.tileWidth
                    height: Math.round(grid.tileWidth * 9 / 16)
                    radius: Theme.radius
                    color: Theme.fillTrack

                    FocusRing {
                        visible: tiles.activeFocus && tiles.cursor === tile.index
                    }

                    Image {
                        id: picture

                        // The picture itself only until its thumbnail exists, which is saved from this once it is decoded, laid out and in a window to be grabbed from. Not straight off the status: a picture the pixmap cache already holds is ready while the tile is still being built, at no size and in no window.
                        readonly property string thumbnail: Wallpaper.thumbnail(tile.modelData)
                        readonly property bool keepable: picture.status === Image.Ready && picture.thumbnail === "" && picture.width > 0 && picture.Window.window !== null

                        anchors.fill: parent
                        anchors.margins: tile.chosen ? 3 : 0

                        source: picture.thumbnail !== "" ? picture.thumbnail : Wallpaper.fileUrl(tile.modelData)
                        sourceSize.width: 256
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true

                        onKeepableChanged: {
                            if (picture.keepable)
                                Wallpaper.keep(tile.modelData, picture);
                        }

                        opacity: tile.chosen || tileMouse.containsMouse || (tiles.activeFocus && tiles.cursor === tile.index) ? 1 : 0.72

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durationFast
                            }
                        }
                    }

                    // Over the image rather than under it, so the ring is drawn whole instead of hidden behind the picture it frames.
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Theme.radius
                        border.width: tile.chosen ? 2 : 0
                        border.color: Theme.accent
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: grid.picked(tile.modelData)
                    }
                }
            }
        }

        PanelMessage {
            width: parent.width
            visible: Wallpaper.images.length === 0
            text: "No images in " + Wallpaper.folder + "."
        }
    }

    function componentFor(key: string): Component {
        switch (key) {
        case "wallpaper":
            return wallpaperPage;
        case "bar":
            return barPage;
        case "notifications":
            return notificationsPage;
        case "general":
            return generalPage;
        case "displays":
            return displaysPage;
        case "lock":
            return lockPage;
        case "theme":
            return themePage;
        default:
            return appearancePage;
        }
    }

    // One block per page. Outside a search only the current one is built; during one, every page but Displays, whose canvas has nothing a search could name and polls hyprctl while it exists.
    Column {
        id: pageStack

        readonly property bool anyHit: {
            for (let index = 0; index < blocks.count; index++) {
                const block = blocks.itemAt(index);
                if (block && block.hit)
                    return true;
            }
            return false;
        }

        width: parent.width
        spacing: 28

        Repeater {
            id: blocks

            model: root.pageKeys

            delegate: Column {
                id: block

                required property string modelData

                readonly property string searchTitle: root.titleOf(block.modelData)
                readonly property bool built: root.searching ? block.modelData !== "displays" : block.modelData === root.page
                readonly property bool hit: root.searching && blockLoader.item !== null && root.anyHit(blockLoader.item.children)

                width: pageStack.width
                spacing: 14
                visible: block.built && (!root.searching || block.hit)

                // The page a group of results came from, and the way to it.
                Item {
                    width: parent.width
                    height: 22
                    visible: root.searching

                    Text {
                        id: blockTitle

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        textFormat: Text.PlainText
                        text: block.searchTitle
                        color: blockMouse.containsMouse ? Theme.accent : Theme.textPrimary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Theme.fontWeightStrong
                    }

                    IconText {
                        anchors.left: blockTitle.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        fillBarHeight: false
                        text: Glyphs.angleRight
                        color: blockMouse.containsMouse ? Theme.accent : Theme.textMuted
                        font.pixelSize: 9
                    }

                    MouseArea {
                        id: blockMouse

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: blockTitle.implicitWidth + 24
                        hoverEnabled: true
                        onClicked: root.pageRequested(block.modelData)
                    }
                }

                Loader {
                    id: blockLoader

                    width: parent.width
                    active: block.built
                    sourceComponent: root.componentFor(block.modelData)
                }
            }
        }

        PanelMessage {
            width: parent.width
            visible: root.searching && !pageStack.anyHit
            text: "No settings match “" + root.query.trim() + "”."
        }
    }

    Component {
        id: appearancePage

        Column {
            spacing: 18

            Group {
                title: "Accent and hover"

                SwatchRow {
                    label: "Accent colour"
                    options: root.accentColors
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
                    options: root.surfaceColors
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
    }

    Component {
        id: barPage

        Column {
            spacing: 18

            Group {
                title: "Bar"

                SwatchRow {
                    label: "Colour"
                    options: root.barColors
                    current: Settings.barColor
                    onPicked: value => Settings.barColor = value
                }

                SliderRow {
                    label: "Opacity"
                    value: Settings.barOpacity
                    minimum: 0
                    maximum: 1
                    decimals: 2
                    onAdjusted: newValue => Settings.barOpacity = newValue
                }

                SliderRow {
                    label: "Height"
                    value: Settings.barHeight
                    minimum: 24
                    maximum: 48
                    suffix: "px"
                    onAdjusted: newValue => Settings.barHeight = Math.round(newValue)
                }

                SliderRow {
                    label: "Corner radius"
                    value: Settings.barRadius
                    minimum: 0
                    maximum: 20
                    suffix: "px"
                    onAdjusted: newValue => Settings.barRadius = Math.round(newValue)
                }

                ToggleRow {
                    label: "Top border"
                    checked: Settings.showTopBorder
                    onToggled: Settings.showTopBorder = !Settings.showTopBorder
                }

                ToggleRow {
                    label: "Background blur"
                    checked: Settings.barBlur
                    onToggled: Settings.barBlur = !Settings.barBlur
                }
            }

            Group {
                title: "Outer corners"

                ToggleRow {
                    label: "Round into the screen edges"
                    checked: Settings.outerCorners
                    onToggled: Settings.outerCorners = !Settings.outerCorners
                }

                SliderRow {
                    label: "Corner size"
                    value: Settings.outerCornerRadius
                    minimum: 4
                    maximum: 32
                    suffix: "px"
                    onAdjusted: newValue => Settings.outerCornerRadius = Math.round(newValue)
                }
            }

            // Everything here is off out of the box: each one talks to something outside the shell, and a desktop has no battery to report and no reason to run nmcli every few seconds.
            Group {
                title: "Bar components"

                ToggleRow {
                    label: "Wi-Fi and Ethernet"
                    checked: Settings.showNetwork
                    onToggled: Settings.showNetwork = !Settings.showNetwork
                }

                ToggleRow {
                    label: "Bluetooth"
                    checked: Settings.showBluetooth
                    onToggled: Settings.showBluetooth = !Settings.showBluetooth
                }

                ToggleRow {
                    label: "Battery"
                    checked: Settings.showBattery
                    onToggled: Settings.showBattery = !Settings.showBattery
                }

                ToggleRow {
                    label: "Screen recording"
                    checked: Settings.showRecording
                    onToggled: Settings.showRecording = !Settings.showRecording
                }
            }
        }
    }

    Component {
        id: notificationsPage

        Column {
            spacing: 18

            Group {
                title: "Notifications"

                // A string rather than a bool in settings, so a third style later is a third pill rather than a second flag to keep consistent with the first.
                ChoiceRow {
                    label: "Toast style"
                    options: [
                        {
                            value: "integrated",
                            label: "Attached"
                        },
                        {
                            value: "floating",
                            label: "Floating"
                        }
                    ]
                    current: Settings.notificationStyle
                    onPicked: value => Settings.notificationStyle = value
                }

                SliderRow {
                    label: "Width"
                    value: Settings.notificationWidth
                    minimum: 280
                    maximum: 560
                    suffix: "px"
                    onAdjusted: newValue => Settings.notificationWidth = Math.round(newValue)
                }

                SliderRow {
                    label: "Minimum height"
                    value: Settings.notificationHeight
                    minimum: 44
                    maximum: 140
                    suffix: "px"
                    onAdjusted: newValue => Settings.notificationHeight = Math.round(newValue)
                }

                // What a notification that named no timeout of its own gets; critical still waits to be dismissed however this is set.
                SliderRow {
                    label: "Time on screen"
                    value: Settings.notificationSeconds
                    minimum: 2
                    maximum: 30
                    suffix: "s"
                    onAdjusted: newValue => Settings.notificationSeconds = Math.round(newValue)
                }
            }
        }
    }

    Component {
        id: generalPage

        Column {
            spacing: 18

            Group {
                title: "Clock and calendar"

                ToggleRow {
                    label: "Show seconds"
                    checked: Settings.clockShowSeconds
                    onToggled: Settings.clockShowSeconds = !Settings.clockShowSeconds
                }

                ToggleRow {
                    label: "12 hour clock"
                    checked: Settings.clockUse12Hour
                    onToggled: Settings.clockUse12Hour = !Settings.clockUse12Hour
                }

                ToggleRow {
                    label: "Minute progress line"
                    checked: Settings.clockShowProgress
                    onToggled: Settings.clockShowProgress = !Settings.clockShowProgress
                }

                ToggleRow {
                    label: "Calendar opens on year view"
                    checked: Settings.calendarYearView
                    onToggled: Settings.calendarYearView = !Settings.calendarYearView
                }
            }

            Group {
                title: "Overview"

                ToggleRow {
                    label: "Window previews"
                    checked: Settings.overviewPreviews
                    onToggled: Settings.overviewPreviews = !Settings.overviewPreviews
                }
            }
        }
    }

    // hyprctl is only asked for the monitor layout while the page that shows it is built.
    Component {
        id: displaysPage

        DisplayManager {
            Component.onCompleted: Displays.watching = true
            Component.onDestruction: Displays.watching = false
        }
    }

    Component {
        id: wallpaperPage

        Column {
            id: wallpaperColumn

            // Which output a click sets, or all of them; not saved, since it is about the next click rather than a setting.
            property string target: ""

            spacing: 18

            Component.onCompleted: {
                Wallpaper.scan();
                Wallpaper.refresh();
            }

            PanelMessage {
                width: parent.width
                visible: !Wallpaper.available && !root.searching
                warning: true
                text: "awww is not answering, so the desktop wallpaper cannot be changed. Is awww-daemon running?"
            }

            Group {
                title: "Desktop"

                // Only asked with more than one output to tell apart.
                ChoiceRow {
                    applies: Wallpaper.outputs.length > 1
                    label: "Screen"
                    options: [
                        {
                            value: "",
                            label: "All"
                        }
                    ].concat(Wallpaper.outputs.map(name => ({
                                value: name,
                                label: name
                            })))
                    current: wallpaperColumn.target
                    onPicked: value => wallpaperColumn.target = value
                }

                WallpaperGrid {
                    selected: {
                        if (wallpaperColumn.target === "")
                            return Object.values(Wallpaper.current);
                        const shown = Wallpaper.current[wallpaperColumn.target];
                        return shown !== undefined ? [shown] : [];
                    }
                    onPicked: path => Wallpaper.apply(path, wallpaperColumn.target)
                }

                // Only shows once awww draws again, so a change redraws what is on screen rather than waiting for the next pick.
                ChoiceRow {
                    label: "Scaling"
                    options: [
                        {
                            value: "crop",
                            label: "Fill"
                        },
                        {
                            value: "fit",
                            label: "Fit"
                        },
                        {
                            value: "no",
                            label: "Center"
                        }
                    ]
                    current: Settings.wallpaperResize
                    onPicked: value => {
                        Settings.wallpaperResize = value;
                        Wallpaper.reapply();
                    }
                }

                PanelMessage {
                    width: parent.width
                    visible: Wallpaper.lastError !== "" && !root.searching
                    warning: true
                    text: Wallpaper.lastError
                }

                // The lock screen grid lists the same folder.
                FieldRow {
                    label: "Folder"
                    value: Settings.wallpaperFolder
                    placeholder: "~/Pictures/wallpapers"
                    browse: "folder"
                    onCommitted: text => Settings.wallpaperFolder = text.trim()
                }
            }

            Group {
                title: "Transition"

                ChoiceRow {
                    label: "Style"
                    options: Wallpaper.transitions
                    current: Settings.wallpaperTransition
                    onPicked: value => Settings.wallpaperTransition = value
                }

                SliderRow {
                    applies: Settings.wallpaperTransition !== "none"
                    label: "Duration"
                    value: Settings.wallpaperTransitionSeconds
                    minimum: 0.2
                    maximum: 3
                    decimals: 1
                    suffix: "s"
                    onAdjusted: newValue => Settings.wallpaperTransitionSeconds = Math.round(newValue * 10) / 10
                }
            }
        }
    }

    Component {
        id: lockPage

        Column {
            spacing: 18

            // The desktop's wallpaper too, which the button under the grid offers.
            Component.onCompleted: {
                Wallpaper.scan();
                Wallpaper.refresh();
            }

            PanelMessage {
                width: parent.width
                visible: LockConfig.broken && !root.searching
                warning: true
                text: "quicklock.json is there but could not be read. Nothing on this page is saved until it is fixed by hand."
            }

            Group {
                title: "Wallpaper"

                WallpaperGrid {
                    selected: [LockConfig.expand(LockConfig.wallpaper)]
                    onPicked: path => LockConfig.wallpaper = path
                }

                // What the first output is showing; with different pictures on each, the first is as good a pick as any.
                ButtonRow {
                    readonly property string desktop: {
                        const first = Wallpaper.outputs.length > 0 ? Wallpaper.current[Wallpaper.outputs[0]] : undefined;
                        return first !== undefined ? first : "";
                    }

                    label: "Use the desktop wallpaper"
                    enabledAction: desktop !== "" && desktop !== LockConfig.expand(LockConfig.wallpaper)
                    onTriggered: LockConfig.wallpaper = desktop
                }

                FieldRow {
                    label: "Path"
                    value: LockConfig.wallpaper
                    placeholder: "~/Pictures/wallpapers/w.jpg"
                    browse: "file"
                    nameFilters: root.imageFilters
                    onCommitted: text => LockConfig.wallpaper = text
                }
            }

            Group {
                title: "Background effects"

                SliderRow {
                    label: "Dim"
                    value: LockConfig.dim
                    minimum: 0
                    maximum: 1
                    decimals: 2
                    onAdjusted: newValue => LockConfig.dim = Math.round(newValue * 100) / 100
                }

                SliderRow {
                    label: "Blur"
                    value: LockConfig.blur
                    minimum: 0
                    maximum: 128
                    suffix: "px"
                    onAdjusted: newValue => LockConfig.blur = Math.round(newValue)
                }

                SliderRow {
                    label: "Contrast"
                    value: LockConfig.contrast
                    minimum: -1
                    maximum: 1
                    decimals: 2
                    onAdjusted: newValue => LockConfig.contrast = Math.round(newValue * 100) / 100
                }

                SliderRow {
                    label: "Vibrancy"
                    value: LockConfig.vibrancy
                    minimum: -1
                    maximum: 1
                    decimals: 2
                    onAdjusted: newValue => LockConfig.vibrancy = Math.round(newValue * 100) / 100
                }
            }

            // quicklock reads a negative radius as fully round, so the far right of each of these sliders is that rather than a number.
            Group {
                title: "Password field"

                SliderRow {
                    label: "Corner radius"
                    value: LockConfig.rounding < 0 ? 26 : LockConfig.rounding
                    minimum: 0
                    maximum: 26
                    valueText: LockConfig.rounding < 0 ? "round" : LockConfig.rounding + "px"
                    onAdjusted: newValue => LockConfig.rounding = Math.round(newValue) >= 26 ? -1 : Math.round(newValue)
                }

                SliderRow {
                    label: "Dot corner radius"
                    value: LockConfig.dotRounding < 0 ? 6 : LockConfig.dotRounding
                    minimum: 0
                    maximum: 6
                    valueText: LockConfig.dotRounding < 0 ? "round" : LockConfig.dotRounding + "px"
                    onAdjusted: newValue => LockConfig.dotRounding = Math.round(newValue) >= 6 ? -1 : Math.round(newValue)
                }
            }

            Group {
                id: avatarGroup

                readonly property int roundAt: Math.round(LockConfig.avatarSize / 2) + 1

                title: "Avatar"

                FieldRow {
                    label: "Picture"
                    value: LockConfig.avatar
                    placeholder: "~/.face"
                    browse: "file"
                    nameFilters: root.imageFilters
                    onCommitted: text => LockConfig.avatar = text
                }

                SliderRow {
                    label: "Size"
                    value: LockConfig.avatarSize
                    minimum: 48
                    maximum: 240
                    suffix: "px"
                    onAdjusted: newValue => LockConfig.avatarSize = Math.round(newValue)
                }

                SliderRow {
                    label: "Height above centre"
                    value: LockConfig.avatarOffset
                    minimum: 0
                    maximum: 400
                    suffix: "px"
                    onAdjusted: newValue => LockConfig.avatarOffset = Math.round(newValue)
                }

                SliderRow {
                    label: "Corner radius"
                    value: LockConfig.avatarRounding < 0 ? avatarGroup.roundAt : Math.min(LockConfig.avatarRounding, avatarGroup.roundAt)
                    minimum: 0
                    maximum: avatarGroup.roundAt
                    valueText: LockConfig.avatarRounding < 0 ? "round" : LockConfig.avatarRounding + "px"
                    onAdjusted: newValue => LockConfig.avatarRounding = Math.round(newValue) >= avatarGroup.roundAt ? -1 : Math.round(newValue)
                }
            }

            Group {
                title: "Clock"

                FieldRow {
                    label: "Time format"
                    value: LockConfig.timeFormat
                    placeholder: "HH:mm"
                    onCommitted: text => LockConfig.timeFormat = text
                }

                FieldRow {
                    label: "Date format"
                    value: LockConfig.dateFormat
                    placeholder: "dddd, MMMM dd"
                    onCommitted: text => LockConfig.dateFormat = text
                }

                // Read once when the page is built: this is a check that a format means what you think, not a clock.
                PanelMessage {
                    width: parent.width
                    visible: !root.searching
                    text: {
                        const now = new Date();
                        return "Qt date format. Right now that reads " + Qt.formatDateTime(now, LockConfig.timeFormat) + "  ·  " + Qt.formatDateTime(now, LockConfig.dateFormat);
                    }
                }
            }

            Group {
                title: "Behaviour"

                ToggleRow {
                    label: "Keep the screen awake while locked"
                    checked: LockConfig.caffeine
                    onToggled: LockConfig.caffeine = !LockConfig.caffeine
                }

                FieldRow {
                    label: "Caffeine glyph"
                    value: LockConfig.caffeineIcon
                    onCommitted: text => LockConfig.caffeineIcon = text
                }

                FieldRow {
                    label: "Glyph font"
                    value: LockConfig.iconFont
                    placeholder: "Font Awesome 7 Free"
                    onCommitted: text => LockConfig.iconFont = text
                }

                FieldRow {
                    label: "PAM service"
                    value: LockConfig.pam
                    placeholder: "login"
                    onCommitted: text => LockConfig.setPam(text.trim())
                }

                PanelMessage {
                    width: parent.width
                    visible: LockConfig.pamError !== "" && !root.searching
                    warning: true
                    text: LockConfig.pamError
                }
            }

            // Only this page's: the one in the sidebar is the shell's own look and leaves quicklock.json alone.
            ButtonRow {
                label: "Restore lock screen defaults"
                onTriggered: LockConfig.restoreDefaults()
            }
        }
    }

    Component {
        id: themePage

        Column {
            spacing: 18

            Component.onCompleted: SystemTheme.refresh()

            PanelMessage {
                width: parent.width
                visible: !SystemTheme.loaded && !root.searching
                warning: true
                text: SystemTheme.path + " could not be read. Changes apply to this session but are not kept for the next one."
            }

            Group {
                title: "Applications"

                PickerRow {
                    label: "GTK theme"
                    options: SystemTheme.gtkThemes
                    current: SystemTheme.gtkTheme
                    onPicked: value => SystemTheme.set("gtk_theme", value)
                }

                PickerRow {
                    label: "Icon theme"
                    options: SystemTheme.iconThemes
                    current: SystemTheme.iconTheme
                    onPicked: value => SystemTheme.set("icon_theme", value)
                }
            }

            Group {
                title: "Cursor"

                PickerRow {
                    label: "Cursor theme"
                    options: SystemTheme.cursorThemes
                    current: SystemTheme.cursorTheme
                    onPicked: value => SystemTheme.set("cursor_theme", value)
                }

                ChoiceRow {
                    label: "Size"
                    options: SystemTheme.cursorSizes.map(size => ({
                                value: size,
                                label: String(size)
                            }))
                    current: SystemTheme.cursorSize
                    onPicked: value => SystemTheme.set("cursor_size", value)
                }

                PanelMessage {
                    width: parent.width
                    visible: SystemTheme.cursorError !== "" && !root.searching
                    warning: true
                    text: "Hyprland did not take the cursor: " + SystemTheme.cursorError
                }
            }

            PanelMessage {
                width: parent.width
                visible: !root.searching
                text: "Applied now and saved to hypr/hyprland/theme.lua for the next login, and handed to xsettingsd for X11 apps. Apps that are already open may keep the old theme until they restart."
            }
        }
    }
}
