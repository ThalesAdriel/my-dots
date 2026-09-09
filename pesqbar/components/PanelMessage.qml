import QtQuick
import "root:/config"

// A line of prose under a panel's controls: a note that something the module needs is not installed, or the last thing that went wrong, in red. Four panels had the same ten lines for it.
Text {
    property bool warning: false

    textFormat: Text.PlainText
    color: warning ? Theme.urgent : Theme.textMuted
    font.family: Theme.sansFamily
    font.pixelSize: Theme.fontSizeSmall
    wrapMode: Text.Wrap
    maximumLineCount: 3
    elide: Text.ElideRight
}
