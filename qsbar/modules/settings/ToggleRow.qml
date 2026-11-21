pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Item {
    id: toggleRow

    property string label: ""
    property bool checked: false

    property bool applies: true
    readonly property bool hit: toggleRow.applies && SettingsContext.shows(toggleRow, toggleRow.label)

    signal toggled

    width: parent.width
    height: 34
    visible: toggleRow.hit

    RowLabel {
        anchors.left: parent.left
        anchors.right: toggle.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: toggleRow.label
    }

    Rectangle {
        id: toggle

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        width: 44
        height: 24
        radius: Theme.pill(24)
        color: toggleRow.checked ? Theme.accent : Theme.fillTrack

        activeFocusOnTab: true
        Keys.onSpacePressed: toggleRow.toggled()
        Keys.onReturnPressed: toggleRow.toggled()
        Keys.onEnterPressed: toggleRow.toggled()

        FocusRing {
            radius: Theme.pill(30)
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationBase
            }
        }

        Rectangle {
            width: 18
            height: 18
            radius: Theme.pill(18)
            color: Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
            x: toggleRow.checked ? parent.width - width - 3 : 3

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: toggleRow.toggled()
        }
    }
}
