pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Column {
    id: group

    property string title: ""
    default property alias rows: groupRows.data

    readonly property string searchTitle: group.title
    readonly property bool hit: SettingsContext.searching && SettingsContext.anyHit(groupRows.children)

    width: parent.width
    spacing: 8
    visible: !SettingsContext.searching || group.hit

    // Through `data` rather than as plain children.
    data: [
        Text {
            text: group.title
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightStrong
            font.capitalization: Font.AllUppercase
        },

        Rectangle {
            width: group.width
            height: groupRows.implicitHeight + 24

            radius: Theme.cardRadius
            color: Theme.solidCard

            Column {
                id: groupRows

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12

                spacing: 6
            }
        }
    ]
}
