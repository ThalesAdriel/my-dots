pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import "root:/config"
import "root:/services"

// The toast as part of the bar rather than a card of its own: same surface colour, hanging off the bottom edge, rounded like a pill, with a chevron that opens the rest of the body and the app's actions. Everything the notification supplies is read through the Notifications singleton, so the clamping and markup escaping apply here too.
Rectangle {
    id: root

    required property var notification
    property bool showActions: true

    // Inside a shared surface the pill paints no background of its own: the block owns it, so several toasts read as one piece of the bar rather than a stack of cards.
    property bool flat: false

    signal closeRequested

    // A closed notification is destroyed as soon as its handlers return and this card can outlive that by an animation, so nothing reads the object except through here.
    readonly property bool valid: root.notification !== null && root.notification !== undefined

    property bool expanded: false

    readonly property int urgency: root.valid ? root.notification.urgency : NotificationUrgency.Normal
    readonly property bool critical: root.urgency === NotificationUrgency.Critical
    readonly property bool low: root.urgency === NotificationUrgency.Low

    readonly property string summary: root.valid ? Notifications.clampText(root.notification.summary) : ""
    readonly property string body: root.valid ? Notifications.formatBody(root.notification.body) : ""
    readonly property bool hasBody: root.body !== ""
    readonly property string age: root.valid ? Notifications.ageLabel(root.notification) : ""

    readonly property var actions: root.valid && root.notification.actions ? root.notification.actions : []

    readonly property var defaultAction: {
        for (const action of root.actions) {
            if (action.identifier === "default")
                return action;
        }
        return null;
    }
    readonly property var actionList: root.showActions ? root.actions.filter(action => action.identifier !== "default") : []

    readonly property string screenshotPath: root.valid ? Notifications.screenshotPath(root.notification) : ""

    // Only worth a chevron when opening it would show something that is not already on screen.
    readonly property bool expandable: root.actionList.length > 0 || root.screenshotPath !== "" || bodyText.truncated

    property bool imageBroken: false
    property bool iconFailed: false

    // A glyph for the icon this notification named, or "" for a name the shell has none for, and it wins over both of the others: an `audio-volume-high` off the volume keybind resolves to a placeholder square on a machine with no icon theme, which is a valid image as far as the loader is concerned, so the only place to turn it away is before it is asked for. Kept the same as `NotificationCard`.
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

    onExpandableChanged: {
        if (!root.expandable)
            root.expanded = false;
    }

    // invoke() closes the notification unless it is resident, and closing an already closed one is an error rather than a no-op, so nothing else happens here.
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
        implicitHeight: 24
        width: chip.implicitWidth
        height: chip.implicitHeight
        radius: Theme.pill(24)

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
        }

        MouseArea {
            id: chipMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: chip.activated()
        }
    }

    readonly property int horizontalPadding: 12
    readonly property int verticalPadding: 10
    readonly property int iconSize: 34

    implicitHeight: Math.max(Math.max(textColumn.implicitHeight, root.showIcon ? root.iconSize : 0) + root.verticalPadding * 2, Settings.notificationHeight)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.durationBase
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easingCurve
        }
    }

    // The bar's own surface, so the pill and the bar read as one piece of chrome; critical is the one case that gets a border, because an urgent notification that looks exactly like the bar is one nobody sees.
    color: root.flat ? "transparent" : Theme.barBackground
    radius: root.flat ? 0 : Theme.cardRadius
    border.color: Theme.urgent
    border.width: root.critical ? 1 : 0

    // First child, so the buttons and the chevron sit over it and the pill only takes the clicks that missed them.
    MouseArea {
        anchors.fill: parent
        enabled: root.defaultAction !== null
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: event => {
            if (event.button === Qt.RightButton)
                root.closeRequested();
            else
                root.invokeAction(root.defaultAction);
        }
    }

    Item {
        id: iconHolder

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: root.horizontalPadding
        anchors.topMargin: root.verticalPadding

        width: root.showIcon ? root.iconSize : 0
        height: root.showIcon ? root.iconSize : 0

        Rectangle {
            anchors.fill: parent
            radius: Theme.pill(root.iconSize)
            color: Theme.fillTrack
            visible: root.showIcon
        }

        IconText {
            anchors.centerIn: parent
            visible: root.showGlyph

            fillBarHeight: false
            text: root.glyph
            color: root.low ? Theme.textSecondary : Theme.textPrimary
            font.pixelSize: 16
        }

        Item {
            anchors.fill: parent
            anchors.margins: 6

            Image {
                id: iconImage

                anchors.fill: parent
                source: root.iconSource
                visible: root.showImage && iconImage.status === Image.Ready
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: root.iconSize
                sourceSize.height: root.iconSize

                // Notifications point at images that are already gone often enough to be worth handling: drop to the app icon, then to no icon at all rather than to a broken one.
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
    }

    Rectangle {
        id: closeButton

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.horizontalPadding - 4
        anchors.topMargin: root.verticalPadding

        width: 26
        height: 26
        radius: Theme.pill(26)
        color: closeMouse.containsPress ? Theme.fillPressed : closeMouse.containsMouse ? Theme.fillHover : "transparent"

        Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: Glyphs.xmark
            color: Theme.textSecondary
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

    Rectangle {
        id: chevron

        anchors.right: closeButton.left
        anchors.rightMargin: 2
        anchors.top: parent.top
        anchors.topMargin: root.verticalPadding

        width: 26
        height: 26
        radius: Theme.pill(26)

        // Always holds its place even when there is nothing to expand: hiding it would widen the text, which changes whether the body is truncated, which is what decides there is something to expand — a loop.
        opacity: root.expandable ? 1 : 0
        enabled: root.expandable
        color: chevronMouse.containsPress ? Theme.fillPressed : chevronMouse.containsMouse ? Theme.fillHover : "transparent"

        Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: Glyphs.angleDown
            color: Theme.textSecondary
            font.family: Theme.iconFamily
            font.weight: Font.Black
            font.pixelSize: 11

            rotation: root.expanded ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }
        }

        MouseArea {
            id: chevronMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expanded = !root.expanded
        }
    }

    Column {
        id: textColumn

        anchors.left: iconHolder.right
        anchors.leftMargin: root.showIcon ? 10 : root.horizontalPadding
        anchors.right: chevron.left
        anchors.rightMargin: 4
        anchors.top: parent.top
        anchors.topMargin: root.verticalPadding

        spacing: 1

        // Summary and age on one line, the way a phone's notification area writes it; the age is measured from arrival and ticks on its own.
        Item {
            width: textColumn.width
            height: summaryText.implicitHeight

            Rectangle {
                id: urgencyDot

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                width: 6
                height: 6
                radius: Theme.pill(6)
                color: Theme.urgent
                visible: root.critical
            }

            Text {
                id: summaryText

                anchors.left: parent.left
                anchors.leftMargin: root.critical ? 12 : 0
                anchors.verticalCenter: parent.verticalCenter

                textFormat: Text.PlainText
                text: root.summary
                color: root.low ? Theme.textSecondary : Theme.textPrimary
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeightStrong
                elide: Text.ElideRight

                // Never wider than what is left after the age, so a long summary elides rather than pushing "now" off the pill.
                width: Math.min(summaryText.implicitWidth, Math.max(parent.width - ageText.implicitWidth - 14 - (root.critical ? 12 : 0), 0))
            }

            Text {
                id: ageText

                anchors.left: summaryText.right
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter

                textFormat: Text.PlainText
                text: root.age === "" ? "" : "· " + root.age
                color: Theme.textMuted
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Text {
            id: bodyText

            width: textColumn.width
            visible: root.hasBody
            text: root.body
            textFormat: Text.StyledText
            color: Theme.textSecondary
            linkColor: Theme.accent
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            wrapMode: Text.Wrap

            // One line on the pill, the rest behind the chevron.
            maximumLineCount: root.expanded ? 8 : 1

            Behavior on height {
                NumberAnimation {
                    duration: Theme.durationBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easingCurve
                }
            }

            onLinkActivated: link => Notifications.openLink(link)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: bodyText.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }

        Item {
            width: textColumn.width
            height: root.expanded ? actionRow.implicitHeight + 8 : 0
            visible: height > 0
            clip: true

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
    }
}
