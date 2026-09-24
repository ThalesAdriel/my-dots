import QtQuick
import QtQuick.Effects
import qs.config

Item {
    id: root

    readonly property bool resolved: photo.status === Image.Ready

    implicitWidth: Config.avatarSize
    implicitHeight: Config.avatarSize

    visible: Config.avatar.length > 0
    opacity: root.resolved ? 1 : 0
    scale: root.resolved ? 1 : 0.92

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animNormal
            easing.type: Easing.OutQuad
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Config.animNormal
            easing.type: Easing.OutBack
        }
    }

    Image {
        id: photo

        anchors.fill: parent
        source: Config.avatar
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Config.avatarSize
        sourceSize.height: Config.avatarSize
        asynchronous: true
        cache: false
        smooth: true
        mipmap: false
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: Config.radius(Config.avatarRounding, width)
        color: "white"
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    MultiEffect {
        anchors.fill: parent
        source: photo
        visible: root.resolved
        maskEnabled: true
        maskSource: mask
    }

    Rectangle {
        anchors.fill: parent
        radius: Config.radius(Config.avatarRounding, width)
        color: "transparent"
        visible: root.resolved
        border.width: Config.avatarRing
        border.color: Config.entryBorder
    }
}
