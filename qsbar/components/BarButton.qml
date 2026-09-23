import QtQuick
import "root:/config"

Rectangle {
    id: root

    default property alias barContent: contentRow.data
    property alias overlayContent: overlayHolder.data

    property int horizontalPadding: Theme.iconPadding
    property int leftPadding: root.horizontalPadding
    property int rightPadding: root.horizontalPadding
    property int contentSpacing: Theme.iconPadding
    property bool interactive: true
    property bool highlighted: false
    property bool doubleClickEnabled: false
    property alias containsMouse: mouseArea.containsMouse

    signal primaryClicked
    signal doubleClicked
    signal secondaryClicked
    signal middleClicked
    signal scrolled(int steps)

    implicitWidth: contentRow.implicitWidth + root.leftPadding + root.rightPadding
    implicitHeight: Theme.barHeight

    radius: Theme.hoverRadius
    color: {
        if (!root.interactive)
            return "transparent";
        if (mouseArea.containsPress)
            return Theme.fillPressed;
        if (mouseArea.containsMouse)
            return Theme.fillHover;
        if (root.highlighted)
            return Theme.fillHover;
        return "transparent";
    }

    data: [
        Row {
            id: contentRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.leftPadding
            spacing: root.contentSpacing
        },

        Item {
            id: overlayHolder
            anchors.fill: parent
        },

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: root.interactive
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: event => {
                if (event.button === Qt.LeftButton)
                    root.primaryClicked();
                else if (event.button === Qt.RightButton)
                    root.secondaryClicked();
                else if (event.button === Qt.MiddleButton)
                    root.middleClicked();
            }

            onDoubleClicked: event => {
                if (event.button !== Qt.LeftButton)
                    return;
                if (root.doubleClickEnabled)
                    root.doubleClicked();
                else
                    root.primaryClicked();
            }

            onWheel: event => {
                const steps = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : event.angleDelta.x / 120;
                if (steps !== 0)
                    root.scrolled(steps > 0 ? Math.ceil(steps) : Math.floor(steps));
            }
        }
    ]
}
