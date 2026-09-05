import QtQuick
import "root:/config"

Text {
    id: root

    property bool fillBarHeight: true

    height: root.fillBarHeight ? Theme.barHeight : implicitHeight
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    font.family: Theme.iconFamily
    font.weight: Font.Black
    font.pixelSize: Theme.iconSize
    color: Theme.textPrimary
}
