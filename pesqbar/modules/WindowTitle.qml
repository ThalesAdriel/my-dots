import QtQuick
import Quickshell.Wayland
import "root:/config"
import "root:/components"

Item {
    id: root

    property int maximumWidth: 340

    readonly property var activeWindow: ToplevelManager.activeToplevel

    readonly property string displayText: {
        if (!root.activeWindow)
            return "";
        const title = root.activeWindow.title;
        if (title !== undefined && title !== "")
            return title;
        const appId = root.activeWindow.appId;
        return appId !== undefined ? appId : "";
    }

    property bool resolved: false

    implicitWidth: root.resolved ? Math.min(label.implicitWidth, root.maximumWidth) + Theme.groupMargin * 2 : 120
    implicitHeight: Theme.barHeight

    onDisplayTextChanged: {
        root.resolved = true;
        fadeIn.restart();
    }

    Timer {
        interval: 900
        running: !root.resolved
        onTriggered: root.resolved = true
    }

    Skeleton {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.groupMargin
        width: 104
        height: 10
        active: !root.resolved
    }

    Text {
        id: label

        anchors.fill: parent
        anchors.leftMargin: Theme.groupMargin
        anchors.rightMargin: Theme.groupMargin

        visible: root.resolved
        textFormat: Text.PlainText
        text: root.displayText
        color: Theme.textPrimary
        font.family: Theme.sansFamily
        font.pixelSize: Theme.fontSize
        font.weight: Theme.fontWeightNormal
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    NumberAnimation {
        id: fadeIn

        target: label
        property: "opacity"
        from: 0.3
        to: 1
        duration: Theme.durationFast
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easingCurve
    }
}
