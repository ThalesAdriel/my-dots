pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

// One page of the settings window, picked by `page`, or with a `query` every page at once filtered down to the rows that match.
Item {
    id: root

    property string page: "appearance"

    // The search field's text.
    property string query: ""
    readonly property bool searching: root.query.trim() !== ""
    readonly property string needle: root.query.trim().toLowerCase()

    // The window's list of { key, title }, for the headings over each page in the results.
    property var pages: []
    readonly property var pageKeys: ["appearance", "wallpaper", "bar", "notifications", "general", "displays", "lock", "greeter", "theme", "apps"]

    // A heading in the results was clicked: the window leaves the search for that page.
    signal pageRequested(string key)

    function titleOf(key: string): string {
        for (const entry of root.pages) {
            if (entry.key === key)
                return entry.title;
        }
        return key;
    }

    // Whether a row stays up for the current query.
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

    // Whether anything among these children is a row that matched.
    function anyHit(children: var): bool {
        for (let index = 0; index < children.length; index++) {
            if (children[index].hit === true)
                return true;
        }
        return false;
    }

    // One palette for the bar and the panels, so a colour picked for one is there to pick for the other.
    readonly property var surfaceColors: ["#000000", "#11121a", "#141414", "#1b1b1b", "#202020", "#1c2226", "#2e3436", "#241f31", "#3d3846", "#613583", "#813d9c", "#9c1d5e", "#c2407a"]
    // The last two are libadwaita's purple and pink accents, bright enough to read as an accent and still dark enough for the white text drawn on top of it.
    readonly property var accentColors: ["#3584e4", "#2ec27e", "#f5c211", "#ff7800", "#e01b24", "#986a44", "#9141ac", "#d56199"]

    // What the picture fields list when browsing: what Qt, with qt6-imageformats, can draw.
    readonly property var imageFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]

    implicitHeight: pageStack.implicitHeight

    // A titled card holding one group of settings.
    component Group: Column {
        id: group

        property string title: ""
        default property alias rows: groupRows.data

        readonly property string searchTitle: group.title
        readonly property bool hit: root.searching && root.anyHit(groupRows.children)

        width: parent.width
        spacing: 8
        visible: !root.searching || group.hit

        // Through `data` rather than as plain children.
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

        // What the number on the right reads.
        property string valueText: sliderRow.value.toFixed(sliderRow.decimals) + sliderRow.suffix

        // Set false where the row only means something some of the time, rather than overriding `visible`.
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

            // A twentieth of the range a press.
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

    component SwatchRow: Column {
        id: swatchRow

        property string label: ""
        property var options: []
        property string current: ""
        property bool picking: false

        // A colour that is none of the swatches, picked with the picker or typed into the file by hand.
        readonly property bool custom: swatchRow.current !== "" && swatchRow.options.indexOf(swatchRow.current.toLowerCase()) === -1

        property bool applies: true
        readonly property bool hit: swatchRow.applies && root.shows(swatchRow, swatchRow.label)

        signal picked(string value)

        width: parent.width
        spacing: 4
        visible: swatchRow.hit

        Item {
            width: parent.width
            height: 34

            RowLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: swatchRow.label
            }

            // One Tab stop for the row, like a set of radio buttons, with the arrows walking the choice and Enter opening the picker.
            FocusRing {
                target: swatches
            }

            Row {
                id: swatches

                function step(delta: int): void {
                    const index = swatchRow.options.indexOf(swatchRow.current.toLowerCase());
                    const next = Math.min(Math.max(index < 0 ? 0 : index + delta, 0), swatchRow.options.length - 1);
                    swatchRow.picked(swatchRow.options[next]);
                }

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                activeFocusOnTab: true
                Keys.onLeftPressed: swatches.step(-1)
                Keys.onRightPressed: swatches.step(1)
                Keys.onReturnPressed: swatchRow.picking = !swatchRow.picking
                Keys.onEnterPressed: swatchRow.picking = !swatchRow.picking
                Keys.onSpacePressed: swatchRow.picking = !swatchRow.picking

                Repeater {
                    model: swatchRow.options

                    delegate: Rectangle {
                        id: swatch

                        required property string modelData

                        readonly property bool chosen: swatchRow.current.toLowerCase() === swatch.modelData

                        width: 22
                        height: 22
                        radius: Theme.radius
                        color: swatch.modelData
                        border.width: swatch.chosen ? 2 : 1
                        border.color: swatch.chosen ? Theme.textPrimary : Theme.cardBorder

                        MouseArea {
                            anchors.fill: parent
                            onClicked: swatchRow.picked(swatch.modelData)
                        }
                    }
                }

                // Any other colour: shows it once one is in use, and opens the picker either way.
                Rectangle {
                    width: 22
                    height: 22
                    radius: Theme.radius
                    color: swatchRow.custom ? swatchRow.current : customMouse.containsMouse ? Theme.fillHover : Theme.fillTrack
                    border.width: swatchRow.custom || swatchRow.picking ? 2 : 1
                    border.color: swatchRow.custom || swatchRow.picking ? Theme.textPrimary : Theme.cardBorder

                    IconText {
                        anchors.centerIn: parent
                        fillBarHeight: false
                        visible: !swatchRow.custom
                        text: swatchRow.picking ? Glyphs.xmark : Glyphs.plus
                        color: Theme.textSecondary
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: customMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: swatchRow.picking = !swatchRow.picking
                    }
                }
            }
        }

        Loader {
            width: parent.width
            active: swatchRow.picking
            visible: active

            sourceComponent: ColorPicker {
                value: swatchRow.current
                onPicked: value => swatchRow.picked(value)
            }
        }
    }

    // Any colour at all.
    component ColorPicker: Rectangle {
        id: picker

        property string value: ""

        property real hue: 0
        property real saturation: 0
        property real brightness: 0

        // What this last sent, so its own change coming back as `value` does not move the cursors.
        property string sent: ""

        signal picked(string value)

        function load(): void {
            const color = Qt.color(picker.value !== "" ? picker.value : "#000000");

            // A grey has no hue of its own; the strip stays where it was rather than jumping to red.
            if (color.hsvHue >= 0)
                picker.hue = color.hsvHue;
            picker.saturation = color.hsvSaturation;
            picker.brightness = color.hsvValue;
            hexField.text = color.toString();
        }

        function send(): void {
            picker.sent = Qt.hsva(picker.hue, picker.saturation, picker.brightness, 1).toString();
            hexField.text = picker.sent;
            picker.picked(picker.sent);
        }

        function clamp(value: real): real {
            return Math.min(Math.max(value, 0), 1);
        }

        onValueChanged: {
            if (picker.value.toLowerCase() !== picker.sent)
                picker.load();
        }
        Component.onCompleted: picker.load()

        implicitHeight: pickerColumn.implicitHeight + 24
        radius: Theme.radius
        color: Theme.fillTrack

        Column {
            id: pickerColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            Rectangle {
                id: field

                width: parent.width
                height: 120
                radius: Theme.radius
                color: Qt.hsva(picker.hue, 1, 1, 1)

                activeFocusOnTab: true
                Keys.onLeftPressed: {
                    picker.saturation = picker.clamp(picker.saturation - 0.02);
                    picker.send();
                }
                Keys.onRightPressed: {
                    picker.saturation = picker.clamp(picker.saturation + 0.02);
                    picker.send();
                }
                Keys.onUpPressed: {
                    picker.brightness = picker.clamp(picker.brightness + 0.02);
                    picker.send();
                }
                Keys.onDownPressed: {
                    picker.brightness = picker.clamp(picker.brightness - 0.02);
                    picker.send();
                }

                FocusRing {}

                // White fading out to the right, then black fading in towards the bottom, over the pure hue.
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "#ffffffff"
                        }
                        GradientStop {
                            position: 1
                            color: "#00ffffff"
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#00000000"
                        }
                        GradientStop {
                            position: 1
                            color: "#ff000000"
                        }
                    }
                }

                // Filled with the colour itself inside a white ring and a dark one.
                Rectangle {
                    x: picker.saturation * field.width - width / 2
                    y: (1 - picker.brightness) * field.height - height / 2
                    z: 1
                    width: 18
                    height: 18
                    radius: 9
                    color: Qt.hsva(picker.hue, picker.saturation, picker.brightness, 1)
                    border.width: 1
                    border.color: "#000000"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: width / 2
                        color: "transparent"
                        border.width: 2
                        border.color: "#ffffff"
                    }
                }

                // preventStealing.
                MouseArea {
                    function take(mouse: var): void {
                        picker.saturation = picker.clamp((mouse.x - 9) / field.width);
                        picker.brightness = 1 - picker.clamp((mouse.y - 9) / field.height);
                        picker.send();
                    }

                    anchors.fill: parent
                    anchors.margins: -9
                    cursorShape: Qt.CrossCursor
                    preventStealing: true
                    onPressed: mouse => take(mouse)
                    onPositionChanged: mouse => take(mouse)
                }
            }

            Rectangle {
                id: strip

                width: parent.width
                height: 14
                radius: Theme.radius

                activeFocusOnTab: true
                Keys.onLeftPressed: {
                    picker.hue = (picker.hue + 359 / 360) % 1;
                    picker.send();
                }
                Keys.onRightPressed: {
                    picker.hue = (picker.hue + 1 / 360) % 1;
                    picker.send();
                }

                FocusRing {}

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "#ff0000"
                    }
                    GradientStop {
                        position: 1 / 6
                        color: "#ffff00"
                    }
                    GradientStop {
                        position: 2 / 6
                        color: "#00ff00"
                    }
                    GradientStop {
                        position: 3 / 6
                        color: "#00ffff"
                    }
                    GradientStop {
                        position: 4 / 6
                        color: "#0000ff"
                    }
                    GradientStop {
                        position: 5 / 6
                        color: "#ff00ff"
                    }
                    GradientStop {
                        position: 1
                        color: "#ff0000"
                    }
                }

                Rectangle {
                    x: picker.hue * strip.width - width / 2
                    z: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: strip.height + 8
                    radius: 3
                    color: Qt.hsva(picker.hue, 1, 1, 1)
                    border.width: 2
                    border.color: "#ffffff"
                }

                MouseArea {
                    function take(mouse: var): void {
                        // Short of 1, which is red again, so dragging off the right end stays on magenta.
                        picker.hue = Math.min(picker.clamp(mouse.x / strip.width), 0.999);
                        picker.send();
                    }

                    anchors.fill: parent
                    anchors.topMargin: -6
                    anchors.bottomMargin: -6
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onPressed: mouse => take(mouse)
                    onPositionChanged: mouse => take(mouse)
                }
            }

            Item {
                width: parent.width
                height: 30

                Rectangle {
                    id: preview

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 24
                    radius: Theme.radius
                    color: picker.value !== "" ? picker.value : "#000000"
                    border.width: 1
                    border.color: Theme.cardBorder
                }

                // Taken on Enter or on leaving the field, with or without the #, and only once it is six hex digits.
                TextField {
                    id: hexField

                    anchors.left: preview.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 130

                    placeholder: "#rrggbb"

                    onEditingFinished: {
                        const match = hexField.text.trim().match(/^#?([0-9a-fA-F]{6})$/);
                        if (!match) {
                            hexField.text = picker.value;
                            return;
                        }
                        picker.sent = "#" + match[1].toLowerCase();
                        picker.picked(picker.sent);
                        picker.load();
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

    // A handful of named values side by side, the chosen one lit.
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

    // A number nudged a step at a time with − and +, where the exact figure matters more than a slider can show it.
    component StepperRow: Item {
        id: stepperRow

        property string label: ""
        property real value: 0
        property real minimum: 0
        property real maximum: 1
        property real step: 1
        property int decimals: 0

        property bool applies: true
        readonly property bool hit: stepperRow.applies && root.shows(stepperRow, stepperRow.label)

        signal adjusted(real newValue)

        // Rounded to the shown decimals, so a hundred steps of 0.01 land on a number rather than on 0.9999999.
        function nudge(direction: int): void {
            const next = Math.min(Math.max(stepperRow.value + direction * stepperRow.step, stepperRow.minimum), stepperRow.maximum);
            stepperRow.adjusted(Number(next.toFixed(stepperRow.decimals)));
        }

        width: parent.width
        height: 34
        visible: stepperRow.hit

        RowLabel {
            anchors.left: parent.left
            anchors.right: stepper.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: stepperRow.label
        }

        Row {
            id: stepper

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: 54
                height: 26
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: stepperRow.value.toFixed(stepperRow.decimals)
                color: Theme.textPrimary
                font.family: Theme.monoFamily
                font.pixelSize: Theme.fontSizeSmall
            }

            PanelButton {
                label: "−"
                implicitWidth: 26
                onActivated: stepperRow.nudge(-1)
            }

            PanelButton {
                label: "+"
                implicitWidth: 26
                onActivated: stepperRow.nudge(1)
            }
        }
    }

    // A line of text that saves itself when Enter is pressed or the focus leaves it.
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

        // Built when opened and let go when closed.
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

    // A folder's contents, walked by clicking, under a FieldRow.
    component FileBrowser: Rectangle {
        id: browser

        // Picking a folder rather than a file.
        property bool folders: false
        property var nameFilters: []

        // The field's value.
        property string start: ""

        readonly property string home: Quickshell.env("HOME") || "/"

        // The folder on show, kept here and handed to the model rather than read back out of it.
        property string current: ""

        signal chosen(string path)

        // Home written as ~, the way the fields are filled in by hand.
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

        WheelScroller {
            anchors.fill: browserList
            target: browserList
        }

        ListView {
            id: browserList

            anchors.top: browserHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 6
            anchors.leftMargin: 10
            anchors.rightMargin: 10

            height: Math.min(browserList.count, 8) * 30
            clip: true
            spacing: 2
            interactive: false
            model: folderModel

            // The arrows move through the list on their own, ListView does that.
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
                height: 28
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

    // A name picked out of a list too long for pills.
    component PickerRow: Column {
        id: pickerRow

        property string label: ""
        property var options: []
        property string current: ""
        property bool open: false

        // What an option reads as, where the value is not something to show.
        property var labelOf: value => value

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
                    text: pickerRow.current !== "" ? pickerRow.labelOf(pickerRow.current) : "Not set"
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

        // Scrolled by the wheel alone, and the scroller under the list rather than over it.
        Item {
            width: parent.width
            height: pickerList.height
            visible: pickerRow.open && pickerList.count > 0

            WheelScroller {
                anchors.fill: parent
                target: pickerList
            }

            ListView {
                id: pickerList

                width: parent.width
                height: Math.min(pickerList.count, 8) * 30

                clip: true
                spacing: 2
                interactive: false
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
                    height: 28
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
                        text: pickerRow.labelOf(option.modelData)
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
    }

    // The pictures in the wallpaper folder as tiles, the ones in use ringed.
    component WallpaperGrid: Column {
        id: grid

        property var selected: []

        // Folded to one row until asked.
        property bool expanded: false

        signal picked(string path)

        readonly property int across: 4
        readonly property real tileWidth: Math.floor((grid.width - tiles.spacing * (grid.across - 1)) / grid.across)

        // Folded, what is chosen comes first.
        readonly property var shown: {
            const images = Wallpaper.images;
            if (grid.expanded)
                return images;
            const chosen = images.filter(path => grid.selected.indexOf(path) !== -1);
            const rest = images.filter(path => grid.selected.indexOf(path) === -1);
            return chosen.concat(rest).slice(0, grid.across);
        }

        width: parent.width
        spacing: 6

        // Pictures are not settings a search can name.
        visible: !root.searching

        // Above the grid rather than under it.
        ButtonRow {
            applies: Wallpaper.images.length > grid.across
            label: grid.expanded ? "Show fewer" : "Show all " + Wallpaper.images.length + " pictures"
            onTriggered: grid.expanded = !grid.expanded
        }

        Flow {
            id: tiles

            // Where the arrows are, as an index into the pictures; one Tab stop for the grid, like the swatches.
            property int cursor: 0

            function move(delta: int): void {
                tiles.cursor = Math.min(Math.max(tiles.cursor + delta, 0), grid.shown.length - 1);
            }

            width: parent.width
            spacing: 8
            visible: grid.shown.length > 0

            activeFocusOnTab: grid.shown.length > 0
            onActiveFocusChanged: {
                if (!tiles.activeFocus)
                    return;
                const at = grid.shown.findIndex(path => grid.selected.indexOf(path) !== -1);
                tiles.cursor = Math.max(at, 0);
            }
            Keys.onLeftPressed: tiles.move(-1)
            Keys.onRightPressed: tiles.move(1)
            Keys.onUpPressed: tiles.move(-grid.across)
            Keys.onDownPressed: tiles.move(grid.across)
            Keys.onReturnPressed: grid.picked(grid.shown[tiles.cursor])
            Keys.onEnterPressed: grid.picked(grid.shown[tiles.cursor])
            Keys.onSpacePressed: grid.picked(grid.shown[tiles.cursor])

            Repeater {
                model: root.searching ? [] : grid.shown

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

                        // The picture itself only until its thumbnail exists.
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

                    // Over the image rather than under it.
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
        case "greeter":
            return greeterPage;
        case "theme":
            return themePage;
        case "apps":
            return appsPage;
        default:
            return appearancePage;
        }
    }

    // One block per page.
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
                readonly property bool built: root.searching || block.modelData === root.page
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
                    options: root.surfaceColors
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

            // Everything here is off out of the box.
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

                // The cup in the bar: while it is on, hypridle's timeouts under Displays never run.
                ToggleRow {
                    label: "Keep awake"
                    checked: Settings.keepAwake
                    onToggled: Settings.keepAwake = !Settings.keepAwake
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

                // A string rather than a bool in settings.
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

                // What a notification that named no timeout of its own gets.
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

    // hyprctl is only asked for the monitor layout while the page that shows it is open.
    Component {
        id: displaysPage

        Column {
            spacing: 18

            Loader {
                width: parent.width
                active: !root.searching
                visible: active

                sourceComponent: DisplayManager {
                    Component.onCompleted: Displays.watching = true
                    Component.onDestruction: Displays.watching = false
                }
            }

            // hypridle's timeouts, which only run while keep awake, the cup in the bar, is off.
            Group {
                title: "Idle"

                SliderRow {
                    label: "Lock after"
                    value: Settings.idleLockMinutes
                    minimum: 0
                    maximum: 60
                    valueText: Settings.idleLockMinutes === 0 ? "never" : Settings.idleLockMinutes + " min"
                    onAdjusted: newValue => Settings.idleLockMinutes = Math.round(newValue)
                }

                SliderRow {
                    label: "Turn screens off after"
                    value: Settings.idleScreenOffMinutes
                    minimum: 0
                    maximum: 60
                    valueText: Settings.idleScreenOffMinutes === 0 ? "never" : Settings.idleScreenOffMinutes + " min"
                    onAdjusted: newValue => Settings.idleScreenOffMinutes = Math.round(newValue)
                }

                SliderRow {
                    label: "Suspend after"
                    value: Settings.idleSuspendMinutes
                    minimum: 0
                    maximum: 120
                    valueText: Settings.idleSuspendMinutes === 0 ? "never" : Settings.idleSuspendMinutes + " min"
                    onAdjusted: newValue => Settings.idleSuspendMinutes = Math.round(newValue)
                }
            }

            Group {
                title: "Games"

                ChoiceRow {
                    label: "Variable refresh rate"
                    options: [
                        {
                            value: 0,
                            label: "Off"
                        },
                        {
                            value: 2,
                            label: "Fullscreen"
                        },
                        {
                            value: 1,
                            label: "Always"
                        }
                    ]
                    current: Settings.vrr
                    onPicked: value => Settings.vrr = value
                }

                // Games is Hyprland's 2, only for a window that says it is a game.
                ChoiceRow {
                    label: "Direct scanout"
                    options: [
                        {
                            value: 0,
                            label: "Off"
                        },
                        {
                            value: 2,
                            label: "Games"
                        },
                        {
                            value: 1,
                            label: "Fullscreen"
                        }
                    ]
                    current: Settings.directScanout
                    onPicked: value => Settings.directScanout = value
                }

                PanelMessage {
                    width: parent.width
                    visible: Settings.directScanout !== 0 && !root.searching
                    text: "A game that only shows a black screen wants direct scanout off."
                }
            }
        }
    }

    Component {
        id: wallpaperPage

        Column {
            id: wallpaperColumn

            // Which output a click sets, or all of them.
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

                // Only shows once awww draws again.
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

                // What the first output is showing.
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

            // quicklock reads a negative radius as fully round.
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

    // quickgreet, the greetd greeter.
    Component {
        id: greeterPage

        Column {
            spacing: 18

            Component.onCompleted: {
                Wallpaper.scan();
                Wallpaper.refresh();
            }

            PanelMessage {
                width: parent.width
                visible: GreetConfig.missing && !root.searching
                warning: true
                text: "quickgreet is not installed, so nothing on this page is saved. Run ./install.sh config from the dotfiles first."
            }

            PanelMessage {
                width: parent.width
                visible: GreetConfig.broken && !root.searching
                warning: true
                text: "quickgreet.json is there but could not be read. Nothing on this page is saved until it is fixed by hand."
            }

            PanelMessage {
                width: parent.width
                visible: GreetConfig.lastError !== "" && !root.searching
                warning: true
                text: GreetConfig.lastError
            }

            Group {
                title: "Test"

                ButtonRow {
                    label: "Test the login screen"
                    onTriggered: GreetConfig.test()
                }

                PanelMessage {
                    width: parent.width
                    visible: !root.searching
                    text: "Opens it over everything, as it will look at boot. Your password is checked but nobody is signed in; Esc on an empty field or any power button closes it."
                }
            }

            Group {
                title: "Background"

                ChoiceRow {
                    label: "Background"
                    options: [
                        {
                            value: "image",
                            label: "Picture"
                        },
                        {
                            value: "color",
                            label: "Solid colour"
                        }
                    ]
                    current: GreetConfig.background
                    onPicked: value => GreetConfig.background = value
                }

                WallpaperGrid {
                    visible: !root.searching && GreetConfig.background === "image"
                    selected: [GreetConfig.expand(GreetConfig.wallpaper)]
                    onPicked: path => GreetConfig.setPicture("wallpaper", path)
                }

                // What the first output is showing.
                ButtonRow {
                    readonly property string desktop: {
                        const first = Wallpaper.outputs.length > 0 ? Wallpaper.current[Wallpaper.outputs[0]] : undefined;
                        return first !== undefined ? first : "";
                    }

                    label: "Use the desktop wallpaper"
                    applies: GreetConfig.background === "image"
                    enabledAction: desktop !== "" && desktop !== GreetConfig.expand(GreetConfig.wallpaper)
                    onTriggered: GreetConfig.setPicture("wallpaper", desktop)
                }

                FieldRow {
                    label: "Path"
                    applies: GreetConfig.background === "image"
                    value: GreetConfig.wallpaper
                    placeholder: "~/Pictures/wallpapers/w.jpg"
                    browse: "file"
                    nameFilters: root.imageFilters
                    onCommitted: text => GreetConfig.setPicture("wallpaper", text)
                }

                SwatchRow {
                    label: "Colour"
                    applies: GreetConfig.background === "color"
                    options: root.surfaceColors
                    current: GreetConfig.color
                    onPicked: value => GreetConfig.color = value
                }

                SliderRow {
                    label: "Dim"
                    applies: GreetConfig.background === "image"
                    value: GreetConfig.dim
                    minimum: 0
                    maximum: 1
                    decimals: 2
                    onAdjusted: newValue => GreetConfig.dim = Math.round(newValue * 100) / 100
                }

                SliderRow {
                    label: "Blur"
                    applies: GreetConfig.background === "image"
                    value: GreetConfig.blur
                    minimum: 0
                    maximum: 128
                    suffix: "px"
                    onAdjusted: newValue => GreetConfig.blur = Math.round(newValue)
                }
            }

            Group {
                title: "Animation layer"

                PickerRow {
                    label: "ASCII animation"
                    options: GreetConfig.animations
                    current: GreetConfig.animation
                    labelOf: value => GreetConfig.label(value)
                    onPicked: value => GreetConfig.animation = value
                }

                SliderRow {
                    label: "Opacity"
                    applies: GreetConfig.animation !== "none"
                    value: GreetConfig.animationOpacity
                    minimum: 0.05
                    maximum: 1
                    decimals: 2
                    onAdjusted: newValue => GreetConfig.animationOpacity = Math.round(newValue * 100) / 100
                }

                // A slower animation is also a cheaper one: speed sets how often a frame is drawn.
                SliderRow {
                    label: "Speed"
                    applies: GreetConfig.animation !== "none"
                    value: GreetConfig.animationSpeed
                    minimum: 25
                    maximum: 200
                    suffix: "%"
                    onAdjusted: newValue => GreetConfig.animationSpeed = Math.round(newValue / 5) * 5
                }
            }

            Group {
                title: "Login box"

                // The greeter already follows the screen's height; this is on top of that.
                SliderRow {
                    label: "Scale"
                    value: GreetConfig.uiScale * 100
                    minimum: 50
                    maximum: 150
                    suffix: "%"
                    onAdjusted: newValue => GreetConfig.uiScale = Math.round(newValue / 5) / 20
                }

                PickerRow {
                    label: "Border"
                    options: GreetConfig.borders
                    current: GreetConfig.border
                    labelOf: value => GreetConfig.label(value)
                    onPicked: value => GreetConfig.border = value
                }

                SliderRow {
                    label: "Corner radius"
                    value: GreetConfig.rounding
                    minimum: 0
                    maximum: 30
                    suffix: "px"
                    onAdjusted: newValue => GreetConfig.rounding = Math.round(newValue)
                }

                PickerRow {
                    label: "Colour theme"
                    options: GreetConfig.themes
                    current: GreetConfig.theme
                    labelOf: value => GreetConfig.label(value)
                    onPicked: value => GreetConfig.theme = value
                }
            }

            Group {
                title: "Avatar"

                FieldRow {
                    label: "Picture"
                    value: GreetConfig.avatar
                    placeholder: "the account's own, or a silhouette"
                    browse: "file"
                    nameFilters: root.imageFilters
                    onCommitted: text => GreetConfig.setPicture("avatar", text)
                }
            }

            // Only this page's: the one in the sidebar is the shell's own look and leaves quickgreet.json alone.
            ButtonRow {
                label: "Restore login screen defaults"
                onTriggered: GreetConfig.restoreDefaults()
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

                ChoiceRow {
                    label: "Style"
                    options: [
                        {
                            value: "prefer-dark",
                            label: "Dark"
                        },
                        {
                            value: "prefer-light",
                            label: "Light"
                        }
                    ]
                    current: SystemTheme.colorScheme
                    onPicked: value => SystemTheme.set("color_scheme", value)
                }

                ChoiceRow {
                    label: "Title bar buttons"
                    options: [
                        {
                            value: "close",
                            label: "Close"
                        },
                        {
                            value: "all",
                            label: "All"
                        },
                        {
                            value: "none",
                            label: "None"
                        }
                    ]
                    current: SystemTheme.titleButtons
                    onPicked: value => SystemTheme.set("title_buttons", value)
                }

                // libadwaita takes nine named accents rather than a colour.
                ToggleRow {
                    label: "Accent from the bar"
                    checked: SystemTheme.accentFromBar
                    onToggled: SystemTheme.set("accent_from_bar", SystemTheme.accentFromBar ? 0 : 1)
                }

                ToggleRow {
                    label: "Theme Flatpak apps too"
                    checked: SystemTheme.flatpakTheme
                    onToggled: SystemTheme.set("flatpak_theme", SystemTheme.flatpakTheme ? 0 : 1)
                }

                PanelMessage {
                    width: parent.width
                    visible: SystemTheme.flatpakTheme && !root.searching
                    text: "Only a theme in ~/.themes or ~/.local/share/themes reaches Flatpak apps, and some GTK4 apps look wrong with a theme forced on them."
                }
            }

            Group {
                title: "Fonts"

                PickerRow {
                    label: "Interface font"
                    options: SystemTheme.fontFamilies
                    current: SystemTheme.familyOf(SystemTheme.fontName)
                    onPicked: value => SystemTheme.set("font_name", value + " " + SystemTheme.sizeOf(SystemTheme.fontName, 11))
                }

                StepperRow {
                    label: "Interface font size"
                    value: SystemTheme.sizeOf(SystemTheme.fontName, 11)
                    minimum: 6
                    maximum: 32
                    onAdjusted: newValue => SystemTheme.set("font_name", SystemTheme.familyOf(SystemTheme.fontName) + " " + newValue)
                }

                PickerRow {
                    label: "Monospace font"
                    options: SystemTheme.monoFamilies
                    current: SystemTheme.familyOf(SystemTheme.monospaceFontName)
                    onPicked: value => SystemTheme.set("monospace_font_name", value + " " + SystemTheme.sizeOf(SystemTheme.monospaceFontName, 10))
                }

                StepperRow {
                    label: "Monospace font size"
                    value: SystemTheme.sizeOf(SystemTheme.monospaceFontName, 10)
                    minimum: 6
                    maximum: 32
                    onAdjusted: newValue => SystemTheme.set("monospace_font_name", SystemTheme.familyOf(SystemTheme.monospaceFontName) + " " + newValue)
                }

                ChoiceRow {
                    label: "Antialiasing"
                    options: [
                        {
                            value: "none",
                            label: "None"
                        },
                        {
                            value: "grayscale",
                            label: "Grayscale"
                        },
                        {
                            value: "rgba",
                            label: "Subpixel"
                        }
                    ]
                    current: SystemTheme.fontAntialiasing
                    onPicked: value => SystemTheme.set("font_antialiasing", value)
                }

                ChoiceRow {
                    label: "Hinting"
                    options: [
                        {
                            value: "none",
                            label: "None"
                        },
                        {
                            value: "slight",
                            label: "Slight"
                        },
                        {
                            value: "medium",
                            label: "Medium"
                        },
                        {
                            value: "full",
                            label: "Full"
                        }
                    ]
                    current: SystemTheme.fontHinting
                    onPicked: value => SystemTheme.set("font_hinting", value)
                }

                StepperRow {
                    label: "Text scaling factor"
                    value: SystemTheme.textScale
                    minimum: 0.5
                    maximum: 3
                    step: 0.01
                    decimals: 2
                    onAdjusted: newValue => SystemTheme.set("text_scaling_factor", newValue)
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

    Component {
        id: appsPage

        Column {
            spacing: 18

            // Read on every visit, since installing an application or changing a default elsewhere does not tell the shell.
            Component.onCompleted: DefaultApps.refresh()

            PanelMessage {
                width: parent.width
                visible: DefaultApps.lastError !== "" && !root.searching
                warning: true
                text: DefaultApps.lastError
            }

            Group {
                title: "Default applications"

                Repeater {
                    model: DefaultApps.categories

                    delegate: PickerRow {
                        required property var modelData

                        label: modelData.label
                        options: DefaultApps.candidates(modelData.key)
                        current: DefaultApps.current[modelData.key] || ""
                        labelOf: id => DefaultApps.nameOf(id)
                        applies: DefaultApps.available
                        onPicked: value => DefaultApps.set(modelData.key, value)
                    }
                }
            }

            PanelMessage {
                width: parent.width
                visible: !root.searching
                text: "What xdg-open and links clicked in other applications open with, saved to ~/.config/mimeapps.list. Only applications that say they can open that kind of file are listed."
            }
        }
    }
}
