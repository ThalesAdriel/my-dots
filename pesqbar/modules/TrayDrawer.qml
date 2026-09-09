pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "root:/config"
import "root:/components"

Item {
    id: root

    property bool expanded: false

    readonly property var trayItems: SystemTray.items ? SystemTray.items.values : []
    readonly property bool resolved: root.trayItems.length > 0 || settleTimer.expired
    readonly property int itemWidth: Theme.iconSlot + 2
    readonly property int itemSpacing: Theme.iconPadding + 2

    implicitWidth: toggleButton.implicitWidth + drawer.width
    implicitHeight: Theme.barHeight

    Timer {
        id: settleTimer
        property bool expired: false
        interval: 1500
        running: true
        onTriggered: settleTimer.expired = true
    }

    Row {
        anchors.fill: parent
        spacing: 0

        BarButton {
            id: toggleButton

            highlighted: root.expanded
            onPrimaryClicked: root.expanded = !root.expanded

            IconStack {
                IconText {
                    anchors.centerIn: parent
                    text: root.expanded ? Glyphs.collapse : Glyphs.expand
                    color: Theme.textPrimary
                }
            }
        }

        Item {
            id: drawer

            height: Theme.barHeight
            width: root.expanded ? drawerContent.implicitWidth + 10 : 0
            clip: true

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durationDrawer
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }

            Row {
                id: drawerContent

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 5
                spacing: root.itemSpacing

                Repeater {
                    // A plain array rebuilds every delegate whenever the tray changes, and each delegate carries a menu window and a tooltip window: one application adding an icon should not tear down and rebuild the others.
                    model: ScriptModel {
                        values: root.resolved ? root.trayItems : [1, 2, 3]
                    }

                    delegate: Item {
                        id: trayEntry

                        required property int index
                        required property var modelData

                        readonly property bool isPlaceholder: !root.resolved

                        width: root.itemWidth
                        height: Theme.barHeight - 8

                        opacity: root.expanded ? 1 : 0
                        scale: root.expanded ? 1 : 0.6

                        Behavior on opacity {
                            SequentialAnimation {
                                PauseAnimation {
                                    duration: root.expanded ? trayEntry.index * 45 : 0
                                }
                                NumberAnimation {
                                    duration: Theme.durationBase
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easingCurve
                                }
                            }
                        }

                        Behavior on scale {
                            SequentialAnimation {
                                PauseAnimation {
                                    duration: root.expanded ? trayEntry.index * 45 : 0
                                }
                                NumberAnimation {
                                    duration: Theme.durationBase
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.easingCurve
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.hoverRadius
                            visible: !trayEntry.isPlaceholder
                            color: {
                                if (trayMenu.shown)
                                    return Theme.fillHover;
                                return trayMouse.containsPress ? Theme.fillPressed : trayMouse.containsMouse ? Theme.fillHover : "transparent";
                            }
                        }

                        Skeleton {
                            anchors.centerIn: parent
                            width: Theme.iconSize
                            height: Theme.iconSize
                            active: trayEntry.isPlaceholder
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: Theme.iconSize + 4
                            visible: !trayEntry.isPlaceholder
                            source: trayEntry.isPlaceholder ? "" : trayEntry.modelData.icon
                        }

                        TrayMenu {
                            id: trayMenu

                            anchorItem: trayEntry
                            menuHandle: trayEntry.isPlaceholder ? null : trayEntry.modelData.menu
                        }

                        MouseArea {
                            id: trayMouse

                            anchors.fill: parent
                            enabled: !trayEntry.isPlaceholder
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            onClicked: event => {
                                if (event.button === Qt.LeftButton) {
                                    if (trayEntry.modelData.onlyMenu)
                                        trayMenu.toggle();
                                    else
                                        trayEntry.modelData.activate();
                                } else if (event.button === Qt.RightButton) {
                                    trayMenu.toggle();
                                } else {
                                    trayEntry.modelData.secondaryActivate();
                                }
                            }

                            onWheel: event => trayEntry.modelData.scroll(event.angleDelta.x, event.angleDelta.y)
                        }

                        BarTooltip {
                            anchorItem: trayEntry
                            shown: trayMouse.containsMouse && !trayEntry.isPlaceholder && !trayMenu.shown
                            text: {
                                if (trayEntry.isPlaceholder)
                                    return "";
                                const candidates = [trayEntry.modelData.tooltipTitle, trayEntry.modelData.title, trayEntry.modelData.id];
                                for (const candidate of candidates) {
                                    if (typeof candidate === "string" && candidate.length > 0)
                                        return candidate;
                                }
                                return "";
                            }
                        }
                    }
                }
            }
        }
    }
}
