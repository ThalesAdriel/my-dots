import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import qs.config
import qs.services

// The picture qsbar copied in, or else the one AccountsService keeps for whoever is typed into the login, or else a silhouette in the box, as in the mockup.
Item {
    id: root

    // The logins AccountsService has a picture for that the greeter can read, listed once.
    property var accountIcons: ({})
    readonly property string accountIcon: Config.entry(root.accountIcons, Auth.login) ? "file:///var/lib/AccountsService/icons/" + Auth.login : ""
    readonly property bool resolved: photo.status === Image.Ready

    width: Config.avatarSize
    height: Config.avatarSize

    FolderListModel {
        folder: "file:///var/lib/AccountsService/icons"
        showDirs: false
        showDotAndDotDot: false
        showOnlyReadable: true
        sortField: FolderListModel.Unsorted

        onCountChanged: {
            const found = {};
            for (let i = 0; i < count; ++i)
                found[get(i, "fileName")] = true;
            root.accountIcons = found;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Config.radius(Config.rounding, width)
        color: Config.field
        clip: true

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -Math.round(root.height * 0.08)

            visible: !root.resolved
            text: ""
            color: Config.line
            font.family: Config.iconFamily
            font.weight: Font.Black
            font.pixelSize: Math.round(root.height * 0.78)
        }
    }

    Image {
        id: photo

        anchors.fill: parent
        source: Config.avatar !== "" ? Config.avatar : root.accountIcon
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Config.avatarSize
        sourceSize.height: Config.avatarSize
        asynchronous: true
        cache: false
        visible: false
    }

    Rectangle {
        id: mask

        anchors.fill: parent
        radius: Config.radius(Config.rounding, width)
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
        opacity: root.resolved ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animNormal
                easing.type: Easing.OutQuad
            }
        }
    }
}
