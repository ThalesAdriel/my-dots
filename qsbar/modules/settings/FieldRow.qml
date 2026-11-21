pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Column {
    id: fieldRow

    property string label: ""
    property string value: ""
    property string placeholder: ""
    property string browse: ""
    property var nameFilters: []
    property bool browsing: false

    property bool applies: true
    readonly property bool hit: fieldRow.applies && SettingsContext.shows(fieldRow, fieldRow.label)

    signal committed(string text)

    width: parent.width
    spacing: 4
    visible: fieldRow.hit

    Item {
        width: parent.width
        height: 34

        RowLabel {
            anchors.left: parent.left
            anchors.right: field.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: fieldRow.label
        }

        TextField {
            id: field

            anchors.right: browseButton.visible ? browseButton.left : parent.right
            anchors.rightMargin: browseButton.visible ? 6 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(300, fieldRow.width * 0.62) - (browseButton.visible ? browseButton.width + 6 : 0)

            text: fieldRow.value
            placeholder: fieldRow.placeholder

            onEditingFinished: {
                if (field.text !== fieldRow.value)
                    fieldRow.committed(field.text);
                field.text = Qt.binding(() => fieldRow.value);
            }
        }

        PanelButton {
            id: browseButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: fieldRow.browse !== ""
            implicitWidth: 30
            implicitHeight: 30
            glyph: fieldRow.browsing ? Glyphs.xmark : Glyphs.folderOpen
            onActivated: fieldRow.browsing = !fieldRow.browsing
        }
    }

    // Built when opened and let go when closed.
    Loader {
        width: parent.width
        active: fieldRow.browsing
        visible: active

        sourceComponent: FileBrowser {
            folders: fieldRow.browse === "folder"
            nameFilters: fieldRow.nameFilters
            start: fieldRow.value
            onChosen: path => {
                fieldRow.browsing = false;
                fieldRow.committed(path);
            }
        }
    }
}
