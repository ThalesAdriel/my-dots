import QtQuick
import qs.config

Item {
    id: root

    implicitWidth: icon.implicitWidth + Config.userGap + name.implicitWidth
    implicitHeight: Math.max(icon.implicitHeight, name.implicitHeight)

    Text {
        id: icon

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        text: ""
        color: Config.text
        font.family: Config.fontFamilySymbols
        font.pixelSize: Config.userSize
    }

    Text {
        id: name

        anchors.left: icon.right
        anchors.leftMargin: Config.userGap
        anchors.verticalCenter: parent.verticalCenter

        text: Config.user
        color: Config.text
        font.family: Config.fontFamily
        font.pixelSize: Config.userSize
    }
}
