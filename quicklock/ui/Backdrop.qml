import QtQuick
import QtQuick.Effects
import qs.config

Item {
    id: root

    readonly property int downscale: Math.max(1, Config.downscale)
    readonly property int tileWidth: Math.max(1, Math.ceil(root.width / root.downscale))
    readonly property int tileHeight: Math.max(1, Math.ceil(root.height / root.downscale))
    readonly property bool ready: wallpaper.status === Image.Ready

    clip: true

    Rectangle {
        anchors.fill: parent
        color: Config.background
    }

    Item {
        id: tile

        width: root.tileWidth
        height: root.tileHeight
        transformOrigin: Item.TopLeft
        scale: root.downscale
        visible: root.ready
        opacity: root.ready ? 1 : 0

        layer.enabled: true
        layer.smooth: true

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animNormal
                easing.type: Easing.OutQuad
            }
        }

        Image {
            id: wallpaper

            anchors.fill: parent
            source: Config.wallpaper
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: root.tileWidth
            sourceSize.height: root.tileHeight
            asynchronous: true
            cache: false
            smooth: true
            mipmap: false
        }

        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            visible: root.ready
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: Math.max(2, Math.min(64, Math.round(Config.blurRadius / root.downscale)))
            blurMultiplier: 1.0
            contrast: Config.contrast
            saturation: Config.vibrancy
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.ready ? Config.dim : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animNormal
                easing.type: Easing.OutQuad
            }
        }
    }
}
