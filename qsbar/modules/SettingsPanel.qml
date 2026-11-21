pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/modules/settings"

// One page of the settings window, picked by `page`, or with a `query` every page at once filtered down to the rows that match.
Item {
    id: root

    property string page: "appearance"

    property string query: ""
    readonly property bool searching: SettingsContext.searching

    // The window's list of { key, title }, for the headings over each page in the results.
    property var pages: []
    readonly property var pageKeys: root.pages.map(entry => entry.key)

    // A heading in the results was clicked: the window leaves the search for that page.
    signal pageRequested(string key)

    Binding {
        target: SettingsContext
        property: "query"
        value: root.query
    }

    function titleOf(key: string): string {
        for (const entry of root.pages) {
            if (entry.key === key)
                return entry.title;
        }
        return key;
    }

    function sourceFor(key: string): string {
        switch (key) {
        case "wallpaper":
            return "settings/WallpaperPage.qml";
        case "bar":
            return "settings/BarPage.qml";
        case "notifications":
            return "settings/NotificationsPage.qml";
        case "general":
            return "settings/GeneralPage.qml";
        case "displays":
            return "settings/DisplaysPage.qml";
        case "lock":
            return "settings/LockPage.qml";
        case "greeter":
            return "settings/GreeterPage.qml";
        case "theme":
            return "settings/ThemePage.qml";
        case "apps":
            return "settings/AppsPage.qml";
        case "startup":
            return "settings/StartupPage.qml";
        default:
            return "settings/AppearancePage.qml";
        }
    }

    implicitHeight: pageStack.implicitHeight

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
                readonly property bool hit: root.searching && blockLoader.item !== null && SettingsContext.anyHit(blockLoader.item.children)

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
                    source: block.built ? root.sourceFor(block.modelData) : ""
                }
            }
        }

        PanelMessage {
            width: parent.width
            visible: root.searching && !pageStack.anyHit
            text: "No settings match “" + root.query.trim() + "”."
        }
    }
}
