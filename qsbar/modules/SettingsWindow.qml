pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "root:/config"
import "root:/components"
import "root:/services"

// Settings as a window of its own in the middle of the screen: the pages down the left, the one picked on the right. It used to be a sheet sliding over the control center, which left a 368 pixel column for everything including the display canvas, and no room at all for the lock screen or the desktop theme.
Scope {
    id: scope

    readonly property var pages: [
        {
            key: "appearance",
            title: "Appearance",
            glyph: Glyphs.palette
        },
        {
            key: "wallpaper",
            title: "Wallpaper",
            glyph: Glyphs.image
        },
        {
            key: "bar",
            title: "Bar",
            glyph: Glyphs.windowMaximize
        },
        {
            key: "notifications",
            title: "Notifications",
            glyph: Glyphs.bell
        },
        {
            key: "general",
            title: "Clock and overview",
            glyph: Glyphs.sliders
        },
        {
            key: "displays",
            title: "Displays",
            glyph: Glyphs.desktop
        },
        {
            key: "lock",
            title: "Lock screen",
            glyph: Glyphs.lock
        },
        {
            key: "theme",
            title: "System theme",
            glyph: Glyphs.paintbrush
        },
        {
            key: "apps",
            title: "Default applications",
            glyph: Glyphs.apps
        }
    ]

    // Kept across closing and opening again, so the window comes back on the page it was left on.
    property string page: "appearance"

    // Follows UiState, but only once the output is known: set straight off the flag, the window would come up on the old output and then jump.
    property bool open: false

    // The output it was opened on, fixed at that moment: following the focused monitor live would carry the window across screens as the pointer crossed over.
    property string openedOn: ""

    // What the search field at the top of the sidebar holds; the page shows results across every page while it is not empty.
    property alias query: search.text

    function close(): void {
        UiState.settingsOpen = false;
    }

    // Any way of picking a page leaves the search, since the results are not a page of their own to stay on.
    function showPage(key: string): void {
        focusSink.forceActiveFocus();
        scope.query = "";
        scope.page = key;
    }

    function stepPage(delta: int): void {
        const count = scope.pages.length;
        const index = Math.max(scope.pages.findIndex(entry => entry.key === scope.page), 0);
        scope.showPage(scope.pages[(index + delta + count) % count].key);
    }

    onQueryChanged: pageArea.contentY = 0

    Connections {
        target: UiState

        function onSettingsOpenChanged(): void {
            if (UiState.settingsOpen) {
                scope.openedOn = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
                scope.query = "";
            }

            // Whichever way it is closed, a text field still holding the focus gets to save before the page under it is torn down.
            focusSink.forceActiveFocus();
            scope.open = UiState.settingsOpen;
        }
    }

    PanelWindow {
        id: window

        screen: {
            for (const candidate of Quickshell.screens) {
                if (candidate.name === scope.openedOn)
                    return candidate;
            }
            return null;
        }

        // The card and nothing round it, on top of whatever is there, the way fuzzel opens: no anchors puts a layer surface in the middle of the output, and a namespace with no no_anim rule hands the entrance and the exit to Hyprland's own layersIn and layersOut, the same popin fuzzel gets. It used to cover the output with a dimmed backdrop and animate the card itself, which played a second animation inside Hyprland's.
        WlrLayershell.namespace: Theme.panelLayerNamespace
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: scope.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        implicitWidth: Math.min(840, (window.screen ? window.screen.width : 1920) - 48)
        implicitHeight: Math.min(620, (window.screen ? window.screen.height : 1080) - 96)

        exclusiveZone: 0
        color: "transparent"
        visible: scope.open

        // Clicking anywhere else, a keybind that opens something else, or a window taking focus on its own, puts settings away.
        HyprlandFocusGrab {
            windows: [window]
            active: scope.open && window.visible
            onCleared: scope.close()
        }

        Item {
            id: focusSink

            anchors.fill: parent
            focus: true

            // Escape backs out one layer at a time: out of whatever control has the keyboard (a text field saves on the way), then out of the search, then out of settings. A text field does not take Escape, so it arrives here on the way up.
            Keys.onEscapePressed: {
                if (!focusSink.activeFocus)
                    focusSink.forceActiveFocus();
                else if (scope.query !== "")
                    scope.query = "";
                else
                    scope.close();
            }

            // Ctrl+1 to Ctrl+9 and Ctrl+PgUp/PgDn change page from anywhere, Ctrl+F goes to the search. Plain arrows and typing only count while nothing inside has the keyboard, since a slider, a list or a field has its own use for them; typing then starts a search.
            Keys.onPressed: event => {
                const control = (event.modifiers & Qt.ControlModifier) !== 0;
                if (control && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    const index = event.key - Qt.Key_1;
                    if (index < scope.pages.length)
                        scope.showPage(scope.pages[index].key);
                    event.accepted = true;
                } else if (control && (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)) {
                    scope.stepPage(event.key === Qt.Key_PageDown ? 1 : -1);
                    event.accepted = true;
                } else if (control && event.key === Qt.Key_F) {
                    search.focusInput();
                    event.accepted = true;
                } else if (!focusSink.activeFocus) {
                    return;
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    scope.stepPage(event.key === Qt.Key_Down ? 1 : -1);
                    event.accepted = true;
                } else if (event.text.length === 1 && event.text >= " " && event.text !== "\u007f" && (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) === 0) {
                    search.focusInput();
                    search.text += event.text;
                    event.accepted = true;
                }
            }

            Rectangle {
                id: card

                readonly property int padding: 16
                readonly property int sidebarWidth: 188

                anchors.fill: parent

                color: Theme.settingsBackground
                radius: Theme.cardRadius

                // Taking the focus on a click that lands on nothing is what ends an edit in a text field when you click away from it, so the field saves.
                MouseArea {
                    anchors.fill: parent
                    onPressed: focusSink.forceActiveFocus()
                }

                Item {
                    id: header

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: card.padding
                    height: 30

                    IconText {
                        id: headerIcon

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        fillBarHeight: false
                        width: 32
                        text: Glyphs.gear
                        color: Theme.textSecondary
                        font.pixelSize: 15
                    }

                    Text {
                        anchors.left: headerIcon.right
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        text: "Settings"
                        color: Theme.textPrimary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSize + 2
                        font.weight: Theme.fontWeightStrong
                    }

                    // Left out of the Tab order: Escape already does this, and Tab should land on the search first.
                    PanelButton {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        glyph: Glyphs.xmark
                        implicitWidth: 32
                        implicitHeight: 28
                        activeFocusOnTab: false
                        onActivated: scope.close()
                    }
                }

                Item {
                    id: sidebar

                    anchors.top: header.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.topMargin: 14
                    anchors.bottomMargin: card.padding
                    anchors.leftMargin: card.padding

                    width: card.sidebarWidth

                    readonly property int rowHeight: 32
                    readonly property int rowSpacing: 2
                    readonly property int currentIndex: Math.max(scope.pages.findIndex(entry => entry.key === scope.page), 0)

                    // First in the Tab order, and where typing anywhere in the window lands.
                    TextField {
                        id: search

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right

                        placeholder: "Search"
                    }

                    Item {
                        anchors.top: search.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 12
                        height: pageList.implicitHeight

                        // One highlight that slides between rows rather than one per row that blinks on and off, so the eye follows it to the page it landed on. Dimmed while the results are up, since they are not that page.
                        Rectangle {
                            width: parent.width
                            height: sidebar.rowHeight
                            y: sidebar.currentIndex * (sidebar.rowHeight + sidebar.rowSpacing)
                            radius: Theme.radius
                            color: Theme.accent
                            opacity: scope.query !== "" ? 0.3 : 1

                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.durationBase
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easingCurve
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }

                        Column {
                            id: pageList

                            width: parent.width
                            spacing: sidebar.rowSpacing

                            Repeater {
                                model: scope.pages

                                delegate: Rectangle {
                                    id: entry

                                    required property var modelData
                                    required property int index

                                    readonly property bool current: sidebar.currentIndex === entry.index

                                    width: parent.width
                                    height: sidebar.rowHeight
                                    radius: Theme.radius
                                    color: !entry.current && entryMouse.containsMouse ? Theme.fillHover : "transparent"

                                    IconText {
                                        id: entryIcon

                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter

                                        fillBarHeight: false
                                        width: 22
                                        text: entry.modelData.glyph
                                        color: entry.current ? Theme.textPrimary : Theme.textSecondary
                                        font.pixelSize: Theme.fontSizeSmall
                                    }

                                    Text {
                                        anchors.left: entryIcon.right
                                        anchors.right: parent.right
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: entry.modelData.title
                                        color: entry.current ? Theme.textPrimary : Theme.textSecondary
                                        font.family: Theme.sansFamily
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: entry.current ? Theme.fontWeightStrong : Theme.fontWeightNormal
                                        elide: Text.ElideRight
                                    }

                                    // showPage takes the focus first, which ends an edit on the page being left, so it saves rather than being torn down with its text unsubmitted.
                                    MouseArea {
                                        id: entryMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: scope.showPage(entry.modelData.key)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: divider

                    anchors.top: sidebar.top
                    anchors.bottom: sidebar.bottom
                    anchors.left: sidebar.right
                    anchors.leftMargin: card.padding

                    width: 1
                    color: Theme.fillTrack
                }

                Flickable {
                    id: pageArea

                    anchors.top: header.bottom
                    anchors.bottom: parent.bottom
                    anchors.left: divider.right
                    anchors.right: parent.right
                    anchors.topMargin: 14
                    anchors.bottomMargin: card.padding
                    anchors.leftMargin: card.padding

                    // The scroll bar sits in the right margin, so the cards keep the same gap to the edge as the sidebar has on the left.
                    anchors.rightMargin: card.padding

                    clip: true
                    contentWidth: width
                    contentHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0
                    boundsBehavior: Flickable.StopAtBounds

                    // Whatever Tab lands on is scrolled into view, with a little air, so the keyboard never ends up on a control below the fold.
                    readonly property Item focusedItem: Window.activeFocusItem

                    onFocusedItemChanged: pageArea.reveal(pageArea.focusedItem)

                    function reveal(item: Item): void {
                        let inside = false;
                        for (let node = item; node; node = node.parent) {
                            if (node === pageArea.contentItem) {
                                inside = true;
                                break;
                            }
                        }
                        if (!inside)
                            return;

                        const top = item.mapToItem(pageArea.contentItem, 0, 0).y;
                        const bottomLimit = Math.max(pageArea.contentHeight - pageArea.height, 0);
                        if (top < pageArea.contentY + 8)
                            pageArea.contentY = Math.max(top - 16, 0);
                        else if (top + item.height > pageArea.contentY + pageArea.height - 8)
                            pageArea.contentY = Math.min(top + item.height - pageArea.height + 16, bottomLimit);
                    }

                    Loader {
                        id: pageLoader

                        width: pageArea.width

                        // Nothing on a page is built until the window is first opened, and it is all let go again once the window is gone.
                        active: window.visible

                        sourceComponent: SettingsPanel {
                            page: scope.page
                            query: scope.query
                            pages: scope.pages
                            onPageRequested: key => scope.showPage(key)
                        }
                    }
                }

                // Only the shell's own look: the lock screen and the desktop theme live in files of their own and are left alone. Declared after the page so Tab reaches it after the page's own controls rather than before them.
                PanelButton {
                    anchors.left: sidebar.left
                    anchors.right: sidebar.right
                    anchors.bottom: sidebar.bottom
                    height: 28
                    label: "Restore defaults"
                    onActivated: Settings.restoreDefaults()
                }

                // A thin thumb rather than a scroll bar: it only has to say how much more is below, and a track would be a second border down the side of the cards.
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 6

                    y: pageArea.y + pageArea.visibleArea.yPosition * pageArea.height
                    width: 3
                    height: pageArea.visibleArea.heightRatio * pageArea.height
                    radius: Theme.pill(3)

                    visible: pageArea.visibleArea.heightRatio < 1
                    color: Theme.textMuted
                    opacity: pageArea.moving ? 1 : 0.5

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durationBase
                        }
                    }
                }
            }
        }
    }

    // Each page arrives from a few pixels down while it fades in, and the scroll goes back to the top, so a new page never opens halfway down.
    onPageChanged: {
        pageArea.contentY = 0;
        pageEntrance.restart();
    }

    ParallelAnimation {
        id: pageEntrance

        NumberAnimation {
            target: pageLoader
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.durationBase
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easingCurve
        }

        NumberAnimation {
            target: pageLoader
            property: "y"
            from: 10
            to: 0
            duration: Theme.durationBase
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easingCurve
        }
    }

    // What a Hyprland keybind talks to: qs ipc call settings toggle.
    IpcHandler {
        target: "settings"

        function toggle(): void {
            UiState.settingsOpen = !UiState.settingsOpen;
        }

        function open(): void {
            UiState.settingsOpen = true;
        }

        function close(): void {
            scope.close();
        }
    }
}
