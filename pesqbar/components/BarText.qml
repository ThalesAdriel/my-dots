import QtQuick
import "root:/config"

Text {
    // Bar labels carry window titles, SSIDs and tray tooltips, none of which the
    // shell chose. AutoText promotes anything tag-shaped to rich text, and rich
    // text fetches <img src> over the network, so the format is pinned here.
    textFormat: Text.PlainText

    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.sansFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.DemiBold
    color: Theme.textPrimary
}
