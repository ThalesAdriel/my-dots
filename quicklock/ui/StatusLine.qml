import QtQuick
import qs.config
import qs.services

TextLabel {
    text: Battery.label
    visible: Battery.available
    font.pixelSize: Config.statusSize
}
