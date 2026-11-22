pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"
import "root:/components"
import "root:/services"

Column {
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
    visible: !SettingsContext.searching

    // Above the grid rather than under it: expand toggle + rescan button for newly added images.
    Item {
        width: parent.width
        height: 28

        PanelButton {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: Wallpaper.images.length > grid.across
            label: grid.expanded ? "Show fewer" : "Show all " + Wallpaper.images.length + " pictures"
            onActivated: grid.expanded = !grid.expanded
        }

        PanelButton {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: "Rescan (" + Wallpaper.images.length + ")"
            onActivated: {
                Wallpaper.scan();
                Wallpaper.refresh();
            }
        }
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
            model: SettingsContext.searching ? [] : grid.shown

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
                    cache: false
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
