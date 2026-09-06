import QtQuick
import "root:/config"

// The small flat button every panel is built out of: a word, or a single glyph
// where there is no room for one. The network, bluetooth and display panels each
// carried their own copy of this, which had already drifted apart by a couple of
// pixels of padding between them.
Rectangle {
    id: root

    property string label: ""
    property string glyph: ""
    property bool accented: false
    property bool available: true

    readonly property bool iconOnly: root.glyph !== "" && root.label === ""

    signal activated

    implicitWidth: root.iconOnly ? 30 : buttonLabel.implicitWidth + 22
    implicitHeight: 26
    width: root.implicitWidth
    height: root.implicitHeight
    radius: Theme.radius
    opacity: root.available ? 1 : 0.4

    color: {
        if (!root.available)
            return Theme.fillTrack;
        if (buttonMouse.containsPress)
            return Theme.fillPressed;
        if (buttonMouse.containsMouse)
            return Theme.fillHover;
        return root.accented ? Theme.accent : Theme.fillTrack;
    }

    IconText {
        anchors.centerIn: parent
        fillBarHeight: false
        visible: root.iconOnly
        text: root.glyph
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeSmall
    }

    Text {
        id: buttonLabel

        anchors.centerIn: parent
        visible: !root.iconOnly
        text: root.label
        color: Theme.textPrimary
        font.family: Theme.sansFamily
        font.pixelSize: Theme.fontSizeSmall
    }

    MouseArea {
        id: buttonMouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        onClicked: root.activated()
    }
}
