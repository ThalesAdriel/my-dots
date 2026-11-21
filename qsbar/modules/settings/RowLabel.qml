pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Text {
    color: Theme.textSecondary
    font.family: Theme.sansFamily
    font.pixelSize: Theme.fontSizeSmall
    elide: Text.ElideRight
}
