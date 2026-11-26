pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"

// Segmented tab switcher for settings pages that group two related sections.
// Hidden while global search is active so results from every tab show together.
Rectangle {
    id: root

    property var tabs: []
    property string current: ""

    signal picked(string value)

    readonly property int currentIndex: {
        for (let i = 0; i < root.tabs.length; i++) {
            if (root.tabs[i].value === root.current)
                return i;
        }
        return 0;
    }

    width: parent.width
    height: visible ? 34 : 0
    visible: !SettingsContext.searching && root.tabs.length > 1
    radius: Theme.cardRadius
    color: Theme.solidCard

    Item {
        id: track

        anchors.fill: parent
        anchors.margins: 3

        readonly property real tabWidth: root.tabs.length > 0 ? width / root.tabs.length : 0

        Rectangle {
            x: root.currentIndex * track.tabWidth
            y: 0
            width: track.tabWidth
            height: track.height
            radius: Theme.radius
            color: Theme.accent

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: root.tabs

                delegate: Rectangle {
                    id: tabItem

                    required property var modelData
                    required property int index

                    readonly property bool active: root.current === tabItem.modelData.value

                    width: track.tabWidth
                    height: track.height
                    radius: Theme.radius
                    color: !tabItem.active && tabMouse.containsMouse ? Theme.fillHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        textFormat: Text.PlainText
                        text: tabItem.modelData.label
                        color: tabItem.active ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.sansFamily
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: tabItem.active ? Theme.fontWeightStrong : Theme.fontWeightNormal
                    }

                    MouseArea {
                        id: tabMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.picked(tabItem.modelData.value)
                    }
                }
            }
        }
    }
}
