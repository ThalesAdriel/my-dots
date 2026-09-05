import QtQuick
import Quickshell.Services.Mpris
import "root:/config"
import "root:/components"

Card {
    id: root

    readonly property var players: Mpris.players ? Mpris.players.values : []

    readonly property MprisPlayer player: {
        for (const candidate of root.players) {
            if (candidate && candidate.playbackState === MprisPlaybackState.Playing)
                return candidate;
        }
        return root.players.length > 0 ? root.players[0] : null;
    }

    readonly property bool active: root.player !== null

    readonly property bool playing: {
        const player = root.player;
        return player !== null && player.playbackState === MprisPlaybackState.Playing;
    }

    function supports(feature: string): bool {
        const player = root.player;
        return player !== null && player[feature] === true;
    }

    function looping(): bool {
        const player = root.player;
        return player !== null && player.loopState !== MprisLoopState.None;
    }

    implicitHeight: 100
    visible: root.active

    component ControlButton: Rectangle {
        id: control

        property string glyph: ""
        property bool available: true
        property bool engaged: false

        signal triggered

        width: 32
        height: 28
        radius: Theme.radius
        color: {
            if (controlMouse.containsPress)
                return Theme.fillPressed;
            if (controlMouse.containsMouse)
                return Theme.fillHover;
            return control.engaged ? Theme.fillTrack : "transparent";
        }

        IconText {
            anchors.centerIn: parent
            fillBarHeight: false
            text: control.glyph
            color: control.available ? Theme.textPrimary : Theme.textMuted
            font.pixelSize: Theme.fontSizeSmall
        }

        MouseArea {
            id: controlMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: control.available
            onClicked: control.triggered()
        }
    }

    Rectangle {
        id: artHolder

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12

        width: 72
        height: 72
        radius: Theme.radius
        color: Theme.fillTrack
        clip: true

        Image {
            anchors.fill: parent
            source: root.player !== null && root.player.trackArtUrl ? root.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 144
            sourceSize.height: 144
            visible: status === Image.Ready
        }

        IconText {
            anchors.centerIn: parent
            fillBarHeight: false
            visible: root.player === null || !root.player.trackArtUrl
            text: root.playing ? Glyphs.pause : Glyphs.play
            color: Theme.textMuted
            font.pixelSize: 22
        }
    }

    Text {
        id: titleLabel

        anchors.left: artHolder.right
        anchors.right: parent.right
        anchors.top: artHolder.top
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 2

        text: {
            const player = root.player;
            if (player === null || player.trackTitle === "")
                return "Nothing playing";
            return player.trackTitle;
        }
        color: Theme.textPrimary
        font.family: Theme.sansFamily
        font.pixelSize: 14
        font.weight: Theme.fontWeightStrong
        elide: Text.ElideRight
    }

    Text {
        id: artistLabel

        anchors.left: titleLabel.left
        anchors.right: titleLabel.right
        anchors.top: titleLabel.bottom
        anchors.topMargin: 3

        text: {
            const player = root.player;
            if (player === null)
                return "";
            const artist = player.trackArtist;
            const album = player.trackAlbum;
            if (artist !== "" && album !== "")
                return artist + " - " + album;
            return artist !== "" ? artist : album;
        }
        color: Theme.textSecondary
        font.family: Theme.sansFamily
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    Row {
        anchors.left: titleLabel.left
        anchors.top: artistLabel.bottom
        anchors.topMargin: 8
        spacing: 6

        ControlButton {
            glyph: Glyphs.shuffle
            available: root.supports("shuffleSupported")
            engaged: root.supports("shuffle")
            onTriggered: root.player.shuffle = !root.player.shuffle
        }

        ControlButton {
            glyph: Glyphs.previous
            available: root.supports("canGoPrevious")
            onTriggered: root.player.previous()
        }

        ControlButton {
            glyph: root.playing ? Glyphs.pause : Glyphs.play
            available: root.supports("canTogglePlaying")
            onTriggered: root.player.togglePlaying()
        }

        ControlButton {
            glyph: Glyphs.next
            available: root.supports("canGoNext")
            onTriggered: root.player.next()
        }

        ControlButton {
            glyph: Glyphs.repeat
            available: root.supports("loopSupported")
            engaged: root.looping()
            onTriggered: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : MprisLoopState.None
        }
    }
}
