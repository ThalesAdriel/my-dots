pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "root:/config"

BarPopup {
    id: root

    property var menuHandle: null

    readonly property var entries: opener.children ? opener.children.values : []

    alignRight: true

    onShownChanged: {
        if (!root.shown)
            column.expandedIndex = -1;
    }

    QsMenuOpener {
        id: opener
        menu: root.menuHandle
    }

    Item {
        implicitWidth: Math.max(column.implicitWidth + 16, 200)
        implicitHeight: column.implicitHeight + 12

        Column {
            id: column

            property int expandedIndex: -1

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 6
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            Repeater {
                model: root.entries

                delegate: Item {
                    id: entryItem

                    required property int index
                    required property var modelData

                    readonly property bool expanded: column.expandedIndex === entryItem.index
                    readonly property var subEntries: subOpener.children ? subOpener.children.values : []

                    width: column.width
                    implicitWidth: Math.max(rowLabel.implicitWidth + 46, subColumn.implicitWidth)
                    height: entryRow.height + (entryItem.expanded ? subColumn.height : 0)

                    QsMenuOpener {
                        id: subOpener
                        menu: entryItem.modelData.hasChildren ? entryItem.modelData : null
                    }

                    Rectangle {
                        id: entryRow

                        width: parent.width
                        height: entryItem.modelData.isSeparator ? 7 : 28
                        radius: Theme.radius
                        color: {
                            if (entryItem.modelData.isSeparator || !entryItem.modelData.enabled)
                                return "transparent";
                            return entryMouse.containsPress ? Theme.fillPressed : entryMouse.containsMouse ? Theme.fillHover : "transparent";
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            visible: entryItem.modelData.isSeparator
                            color: Theme.popupBorder
                        }

                        Text {
                            id: rowLabel

                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.right: submenuMark.left
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter

                            visible: !entryItem.modelData.isSeparator
                            textFormat: Text.PlainText
                            text: entryItem.modelData.text
                            color: entryItem.modelData.enabled ? Theme.textPrimary : Theme.textMuted
                            font.family: Theme.sansFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }

                        Text {
                            id: submenuMark

                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter

                            visible: entryItem.modelData.hasChildren
                            text: entryItem.expanded ? Glyphs.angleDown : Glyphs.angleRight
                            color: Theme.textMuted
                            font.family: Theme.iconFamily
                            font.weight: Font.Black
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: entryMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !entryItem.modelData.isSeparator && entryItem.modelData.enabled

                            onClicked: {
                                if (entryItem.modelData.hasChildren) {
                                    column.expandedIndex = entryItem.expanded ? -1 : entryItem.index;
                                    return;
                                }
                                entryItem.modelData.triggered();
                                root.shown = false;
                            }
                        }
                    }

                    Column {
                        id: subColumn

                        anchors.top: entryRow.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10

                        visible: entryItem.expanded
                        height: entryItem.expanded ? implicitHeight : 0

                        Repeater {
                            model: entryItem.expanded ? entryItem.subEntries : []

                            delegate: Rectangle {
                                id: subEntry

                                required property var modelData

                                width: subColumn.width
                                height: subEntry.modelData.isSeparator ? 7 : 26
                                radius: Theme.radius
                                color: {
                                    if (subEntry.modelData.isSeparator || !subEntry.modelData.enabled)
                                        return "transparent";
                                    return subMouse.containsPress ? Theme.fillPressed : subMouse.containsMouse ? Theme.fillHover : "transparent";
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    visible: subEntry.modelData.isSeparator
                                    color: Theme.popupBorder
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter

                                    visible: !subEntry.modelData.isSeparator
                                    textFormat: Text.PlainText
                                    text: subEntry.modelData.text
                                    color: subEntry.modelData.enabled ? Theme.textSecondary : Theme.textMuted
                                    font.family: Theme.sansFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: subMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !subEntry.modelData.isSeparator && subEntry.modelData.enabled

                                    onClicked: {
                                        subEntry.modelData.triggered();
                                        root.shown = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
