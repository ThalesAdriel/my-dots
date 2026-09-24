import QtQuick
import "root:/config"

// A line of prose under a panel's controls: a note that something the module needs is not installed, or, with `warning`, the last thing that went wrong. Every warning is an error that only shows once something failed, so it is boxed in red with the alert triangle in front; as a line of red text it read like any other note. Four panels had the same ten lines for it.
Rectangle {
    id: root

    property bool warning: false
    property alias text: label.text

    readonly property int padding: root.warning ? 9 : 0

    implicitWidth: label.implicitWidth + (root.warning ? mark.width + 8 : 0) + root.padding * 2
    implicitHeight: label.implicitHeight + root.padding * 2

    radius: Theme.radius
    color: root.warning ? Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.14) : "transparent"
    border.width: root.warning ? 1 : 0
    border.color: Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.6)

    IconText {
        id: mark

        // Centred on the first line, however many the message wraps to.
        anchors.left: parent.left
        anchors.top: label.top
        anchors.leftMargin: root.padding
        anchors.topMargin: Math.round((label.implicitHeight / Math.max(label.lineCount, 1) - mark.implicitHeight) / 2)

        visible: root.warning
        fillBarHeight: false
        text: Glyphs.triangleExclamation
        color: Theme.urgent
        font.pixelSize: Theme.fontSizeSmall
    }

    Text {
        id: label

        anchors.left: root.warning ? mark.right : parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.warning ? 8 : 0
        anchors.rightMargin: root.padding
        anchors.topMargin: root.padding

        textFormat: Text.PlainText

        // Lighter than the frame, so the words stay readable on the red tint.
        color: root.warning ? Qt.lighter(Theme.urgent, 1.5) : Theme.textMuted
        font.family: Theme.sansFamily
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }
}
