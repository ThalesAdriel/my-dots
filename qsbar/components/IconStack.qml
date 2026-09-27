import QtQuick
import "root:/config"

Item {
    property int slotWidth: Theme.iconSlot

    implicitWidth: slotWidth
    implicitHeight: Theme.barHeight
    height: Theme.barHeight
}
