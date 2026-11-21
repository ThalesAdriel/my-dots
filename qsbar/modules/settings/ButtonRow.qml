pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Rectangle {
    id: buttonRow

    property string label: ""
    property bool enabledAction: true

    property bool applies: true
    readonly property bool hit: buttonRow.applies && SettingsContext.shows(buttonRow, buttonRow.label)

    signal triggered

    function press(): void {
        if (buttonRow.enabledAction)
            buttonRow.triggered();
    }

    width: parent.width
    height: 34
    visible: buttonRow.hit
    radius: Theme.radius
    opacity: buttonRow.enabledAction ? 1 : 0.45

    activeFocusOnTab: buttonRow.enabledAction
    Keys.onSpacePressed: buttonRow.press()
    Keys.onReturnPressed: buttonRow.press()
    Keys.onEnterPressed: buttonRow.press()

    FocusRing {}
    color: {
        if (!buttonRow.enabledAction)
            return Theme.fillTrack;
        if (buttonMouse.containsPress)
            return Theme.fillPressed;
        return buttonMouse.containsMouse ? Theme.fillHover : Theme.fillTrack;
    }

    Text {
        anchors.centerIn: parent
        text: buttonRow.label
        color: Theme.textPrimary
        font.family: Theme.sansFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Theme.fontWeightNormal
    }

    MouseArea {
        id: buttonMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: buttonRow.enabledAction
        onClicked: buttonRow.triggered()
    }
}
