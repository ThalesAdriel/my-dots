import QtQuick
import qs.config
import qs.services

// What the gear opens: one row per installed session, the one that will start lit.
Rectangle {
    id: root

    property bool open: false

    signal picked

    width: Config.menuWidth
    height: rows.implicitHeight + 12
    radius: Config.radius(Config.rounding, 24)
    color: Config.card

    visible: opacity > 0
    opacity: root.open ? 1 : 0
    transform: Translate {
        y: root.open ? 0 : -8

        Behavior on y {
            NumberAnimation {
                duration: Config.animNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animNormal
            easing.type: Easing.OutQuad
        }
    }

    // Clicks between the rows stay in the menu rather than closing it.
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: rows

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        spacing: 5

        Repeater {
            model: Sessions.list

            Rectangle {
                id: row

                required property var modelData
                required property int index
                readonly property bool chosen: row.index === Sessions.current

                width: rows.width
                height: 27
                radius: Config.radius(Config.rounding, height)
                color: rowMouse.containsMouse ? Qt.tint(Config.field, Config.hover) : Config.field
                border.width: row.chosen ? 1 : 0
                border.color: Config.focus

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 9
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: row.modelData.name
                    color: row.chosen ? Config.text : Config.muted
                    font.family: Config.fontFamily
                    font.pixelSize: Config.textSize - 2
                    font.weight: row.chosen ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: rowMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sessions.current = row.index;
                        root.picked();
                    }
                }
            }
        }

        Text {
            width: rows.width
            visible: Sessions.list.length === 0
            wrapMode: Text.Wrap
            text: "No sessions in /usr/share/wayland-sessions"
            color: Config.muted
            font.family: Config.fontFamily
            font.pixelSize: Config.textSize - 2
        }
    }
}
