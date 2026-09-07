pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import "root:/config"
import "root:/services"

Rectangle {
    id: root

    required property var notification
    property int padding: 16
    property bool showActions: true

    signal closeRequested

    // A closed notification is destroyed as soon as its signal handlers return,
    // and a card can outlive that by an animation. Everything below reads
    // through here so a card that lost its notification goes blank rather than
    // throwing on every binding.
    readonly property bool valid: root.notification !== null && root.notification !== undefined

    readonly property int urgency: root.valid ? root.notification.urgency : NotificationUrgency.Normal
    readonly property bool critical: root.urgency === NotificationUrgency.Critical
    readonly property bool low: root.urgency === NotificationUrgency.Low

    readonly property string summary: root.valid ? Notifications.clampText(root.notification.summary) : ""
    readonly property string body: root.valid ? Notifications.formatBody(root.notification.body) : ""
    readonly property bool hasBody: root.body !== ""

    readonly property var actions: root.valid && root.notification.actions ? root.notification.actions : []

    // "default" is what clicking the notification itself does, so it belongs on
    // the card rather than in the button row.
    readonly property var defaultAction: {
        for (const action of root.actions) {
            if (action.identifier === "default")
                return action;
        }
        return null;
    }
    readonly property var actionList: root.showActions ? root.actions.filter(action => action.identifier !== "default") : []

    // Only set when this really is a screenshot and the file it saved is still
    // on disk for an editor to open.
    readonly property string screenshotPath: root.valid ? Notifications.screenshotPath(root.notification) : ""

    property bool imageBroken: false
    property bool iconFailed: false

    // A glyph for the icon this notification named, or "" for a name the shell
    // has none for. A glyph wins over both of the other two: an
    // `audio-volume-high` off the volume keybind has nothing to resolve to on a
    // machine with no icon theme, and what the icon handle draws instead is a
    // placeholder square, which is a perfectly valid image as far as the loader
    // below is concerned. Nothing further down would ever have refused it, so
    // the only place to turn it away is before it is asked for.
    readonly property string glyph: root.valid ? Notifications.iconGlyph(root.notification) : ""

    readonly property string imageSource: root.valid && root.glyph === "" ? Notifications.imageSource(root.notification) : ""
    readonly property string fallbackSource: root.valid && root.glyph === "" ? Notifications.appIconSource(root.notification) : ""

    readonly property string iconSource: !root.imageBroken && root.imageSource !== "" ? root.imageSource : root.fallbackSource
    readonly property bool showImage: root.iconSource !== "" && !root.iconFailed
    readonly property bool showGlyph: !root.showImage && root.glyph !== ""
    readonly property bool showIcon: root.showImage || root.showGlyph

    onImageSourceChanged: {
        root.imageBroken = false;
        root.iconFailed = false;
    }
    onFallbackSourceChanged: root.iconFailed = false

    // invoke() closes the notification on its own unless it is resident, and
    // closing an already closed one is an error rather than a no-op, so the card
    // deliberately does nothing else here.
    function invokeAction(action: var): void {
        if (action)
            action.invoke();
    }

    function editScreenshot(): void {
        Notifications.editScreenshot(root.notification);
        root.closeRequested();
    }

    component ActionChip: Rectangle {
        id: chip

        property string label: ""
        property bool accented: false

        signal activated

        implicitWidth: chipLabel.implicitWidth + 22
        implicitHeight: 26
        width: chip.implicitWidth
        height: chip.implicitHeight
        radius: Theme.radius

        color: {
            if (chipMouse.containsPress)
                return Theme.fillPressed;
            if (chipMouse.containsMouse)
                return Theme.fillHover;
            return chip.accented ? Theme.accent : Theme.fillTrack;
        }

        Text {
            id: chipLabel

            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: chip.label
            color: Theme.textPrimary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Theme.fontWeightNormal
        }

        MouseArea {
            id: chipMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.activated()
        }
    }

    readonly property color summaryColor: root.low ? Theme.textSecondary : Theme.textPrimary
    readonly property color bodyColor: root.low ? Theme.textMuted : Theme.textSecondary

    readonly property color frameColor: {
        if (root.critical)
            return Theme.urgent;
        return root.low ? Qt.rgba(1, 1, 1, 0.07) : Theme.cardBorder;
    }

    readonly property color surfaceColor: {
        if (root.critical)
            return Qt.tint(Theme.cardBackground, Qt.rgba(Theme.urgent.r, Theme.urgent.g, Theme.urgent.b, 0.14));
        return Theme.cardBackground;
    }

    implicitHeight: Math.max(Math.max(textColumn.implicitHeight, root.showIcon ? 32 : 0) + root.padding * 2, Settings.notificationHeight)

    color: root.surfaceColor
    border.color: root.frameColor
    border.width: root.critical ? 1 : Theme.panelBorderWidth
    radius: Theme.cardRadius

    // First child, so everything else sits on top of it and the card only picks
    // up clicks that missed a button or a link.
    MouseArea {
        anchors.fill: parent
        enabled: root.defaultAction !== null
        cursorShape: Qt.PointingHandCursor
        onClicked: root.invokeAction(root.defaultAction)
    }

    Item {
        id: iconHolder

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: root.padding
        anchors.topMargin: root.padding

        width: root.showIcon ? 32 : 0
        height: root.showIcon ? 32 : 0

        IconText {
            anchors.centerIn: parent
            visible: root.showGlyph

            fillBarHeight: false
            text: root.glyph
            color: root.low ? Theme.textSecondary : Theme.textPrimary
            font.pixelSize: 20
        }

        Image {
            id: iconImage

            anchors.fill: parent
            source: root.iconSource
            visible: root.showImage && iconImage.status === Image.Ready
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            sourceSize.width: 32
            sourceSize.height: 32

            // Notifications point at images that are already gone often enough
            // to be worth handling: drop to the app icon, then to no icon at all.
            onStatusChanged: {
                if (iconImage.status !== Image.Error)
                    return;

                if (!root.imageBroken && root.fallbackSource !== "")
                    root.imageBroken = true;
                else
                    root.iconFailed = true;
            }
        }
    }

    Rectangle {
        id: closeButton

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.padding - 6
        anchors.topMargin: root.padding - 6

        width: 22
        height: 22
        radius: Theme.radius
        color: closeMouse.containsPress ? Theme.fillPressed : closeMouse.containsMouse ? Theme.fillHover : "transparent"

        Text {
            anchors.centerIn: parent
            text: Glyphs.xmark
            color: Theme.textMuted
            font.family: Theme.iconFamily
            font.weight: Font.Black
            font.pixelSize: 11
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.closeRequested()
        }
    }

    Column {
        id: textColumn

        anchors.left: iconHolder.right
        anchors.leftMargin: root.showIcon ? 12 : 0
        anchors.right: closeButton.left
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: root.padding

        spacing: 4

        Item {
            width: textColumn.width
            height: summaryText.implicitHeight

            Rectangle {
                id: urgencyDot

                anchors.left: parent.left
                y: Math.max((Theme.fontSize - 7) / 2, 0) + 2

                width: 7
                height: 7
                radius: Theme.pill(7)
                color: Theme.urgent
                visible: root.critical
            }

            Text {
                id: summaryText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.critical ? 14 : 0

                textFormat: Text.PlainText
                text: root.summary
                color: root.summaryColor
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSize
                font.weight: root.low ? Theme.fontWeightNormal : Theme.fontWeightStrong
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
        }

        Text {
            id: bodyText

            width: textColumn.width
            visible: root.hasBody
            text: root.body
            textFormat: Text.StyledText
            color: root.bodyColor
            linkColor: Theme.accent
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            maximumLineCount: root.low ? 3 : 6
            wrapMode: Text.Wrap

            onLinkActivated: link => Notifications.openLink(link)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: bodyText.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        Item {
            width: textColumn.width
            height: actionRow.implicitHeight + 6
            visible: root.actionList.length > 0 || root.screenshotPath !== ""

            Row {
                id: actionRow

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                spacing: 6

                ActionChip {
                    visible: root.screenshotPath !== ""
                    label: "Edit in Satty"
                    accented: true
                    onActivated: root.editScreenshot()
                }

                Repeater {
                    model: root.actionList

                    delegate: ActionChip {
                        id: actionChip

                        required property var modelData

                        label: actionChip.modelData.text
                        onActivated: root.invokeAction(actionChip.modelData)
                    }
                }
            }
        }

        Text {
            width: textColumn.width
            horizontalAlignment: Text.AlignRight
            text: root.valid ? Notifications.ageLabel(root.notification) : ""
            color: Theme.textMuted
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
