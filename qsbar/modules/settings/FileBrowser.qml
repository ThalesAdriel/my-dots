pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "root:/config"
import "root:/components"

Rectangle {
    id: browser

    // Picking a folder rather than a file.
    property bool folders: false
    property var nameFilters: []

    // Where the browser opens: the field's value.
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
