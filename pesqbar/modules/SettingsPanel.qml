pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Item {
    id: root

    readonly property var barColors: ["#11121a", "#000000", "#1b1b1b", "#202020", "#2e3436", "#3d3846"]
    readonly property var surfaceColors: ["#0d0d12", "#000000", "#141414", "#1a1a22", "#1c2226", "#241f31"]
    readonly property var accentColors: ["#3584e4", "#2ec27e", "#f5c211", "#ff7800", "#e01b24", "#986a44"]

    implicitHeight: content.implicitHeight

    // A titled card holding one group of settings. Everything used to run down
    // the panel as one flat list with hairlines between the sections, which read
    // as a wall of rows rather than as five separate things.
    component Group: Column {
        id: group

        property string title: ""
        default property alias rows: groupRows.data

        width: parent.width
        spacing: 8

        // Through `data` rather than as plain children: the default property is
        // aliased to the card's column, so anything declared loose in here would
        // land inside the card with the settings rows.
        data: [
            Text {
                text: group.title
                color: Theme.textMuted
                font.family: Theme.sansFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightStrong
                font.capitalization: Font.AllUppercase
            },

            Rectangle {
                width: group.width
                height: groupRows.implicitHeight + 24

                radius: Theme.cardRadius
                color: Theme.settingsCard
                border.width: Theme.panelBorderWidth
                border.color: Theme.cardBorder

                Column {
                    id: groupRows

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12

                    spacing: 6
                }
            }
        ]
    }

    component SliderRow: Item {
        id: sliderRow

        property string label: ""
        property real value: 0
        property real minimum: 0
        property real maximum: 1
        property int decimals: 0
        property string suffix: ""

        signal adjusted(real newValue)

        width: parent.width
        height: 42

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: sliderRow.label
            color: Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            text: sliderRow.value.toFixed(sliderRow.decimals) + sliderRow.suffix
            color: Theme.textPrimary
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        LevelSlider {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            maximum: 1
            value: sliderRow.maximum > sliderRow.minimum ? (sliderRow.value - sliderRow.minimum) / (sliderRow.maximum - sliderRow.minimum) : 0

            onMoved: newValue => sliderRow.adjusted(sliderRow.minimum + newValue * (sliderRow.maximum - sliderRow.minimum))
        }
    }

    component SwatchRow: Item {
        id: swatchRow

        property string label: ""
        property var options: []
        property string current: ""

        signal picked(string value)

        width: parent.width
        height: 34

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: swatchRow.label
            color: Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: swatchRow.options

                delegate: Rectangle {
                    id: swatch

                    required property string modelData

                    width: 22
                    height: 22
                    radius: Theme.radius
                    color: swatch.modelData
                    border.width: swatchRow.current === swatch.modelData ? 2 : 1
                    border.color: swatchRow.current === swatch.modelData ? Theme.textPrimary : Theme.cardBorder

                    MouseArea {
                        anchors.fill: parent
                        onClicked: swatchRow.picked(swatch.modelData)
                    }
                }
            }
        }
    }

    component ToggleRow: Item {
        id: toggleRow

        property string label: ""
        property bool checked: false

        signal toggled

        width: parent.width
        height: 34

        Text {
            anchors.left: parent.left
            anchors.right: toggle.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: toggleRow.label
            color: Theme.textSecondary
            font.family: Theme.sansFamily
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }

        Rectangle {
            id: toggle

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: 44
            height: 24
            radius: Theme.pill(24)
            color: toggleRow.checked ? Theme.accent : Theme.fillTrack

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

    component ButtonRow: Rectangle {
        id: buttonRow

        property string label: ""
        property bool enabledAction: true

        signal triggered

        width: parent.width
        height: 34
        radius: Theme.radius
        opacity: buttonRow.enabledAction ? 1 : 0.45
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

    Column {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        spacing: 18

        Group {
            title: "Bar"

            SwatchRow {
                label: "Colour"
                options: root.barColors
                current: Settings.barColor
                onPicked: value => Settings.barColor = value
            }

            SliderRow {
                label: "Opacity"
                value: Settings.barOpacity
                minimum: 0
                maximum: 1
                decimals: 2
                onAdjusted: newValue => Settings.barOpacity = newValue
            }

            SliderRow {
                label: "Height"
                value: Settings.barHeight
                minimum: 24
                maximum: 48
                suffix: "px"
                onAdjusted: newValue => Settings.barHeight = Math.round(newValue)
            }

            SliderRow {
                label: "Corner radius"
                value: Settings.barRadius
                minimum: 0
                maximum: 20
                suffix: "px"
                onAdjusted: newValue => Settings.barRadius = Math.round(newValue)
            }

            ToggleRow {
                label: "Top border"
                checked: Settings.showTopBorder
                onToggled: Settings.showTopBorder = !Settings.showTopBorder
            }

            ToggleRow {
                label: "Background blur"
                checked: Settings.barBlur
                onToggled: Settings.barBlur = !Settings.barBlur
            }
        }

        Group {
            title: "Outer corners"

            ToggleRow {
                label: "Round into the screen edges"
                checked: Settings.outerCorners
                onToggled: Settings.outerCorners = !Settings.outerCorners
            }

            SliderRow {
                label: "Corner size"
                value: Settings.outerCornerRadius
                minimum: 4
                maximum: 32
                suffix: "px"
                onAdjusted: newValue => Settings.outerCornerRadius = Math.round(newValue)
            }
        }

        Group {
            title: "Panels"

            SwatchRow {
                label: "Surface colour"
                options: root.surfaceColors
                current: Settings.surfaceColor
                onPicked: value => Settings.surfaceColor = value
            }

            SliderRow {
                label: "Opacity"
                value: Settings.panelOpacity
                minimum: 0.3
                maximum: 1
                decimals: 2
                onAdjusted: newValue => Settings.panelOpacity = newValue
            }

            SliderRow {
                label: "Corner radius"
                value: Settings.panelRadius
                minimum: 0
                maximum: 24
                suffix: "px"
                onAdjusted: newValue => Settings.panelRadius = Math.round(newValue)
            }

            ToggleRow {
                label: "Panel and card borders"
                checked: Settings.showPanelBorders
                onToggled: Settings.showPanelBorders = !Settings.showPanelBorders
            }

            ToggleRow {
                label: "Background blur"
                checked: Settings.panelBlur
                onToggled: Settings.panelBlur = !Settings.panelBlur
            }

            ButtonRow {
                label: "Match bar colour and opacity"
                enabledAction: Settings.surfaceColor !== Settings.barColor || Settings.panelOpacity !== Settings.barOpacity
                onTriggered: {
                    Settings.surfaceColor = Settings.barColor;
                    Settings.panelOpacity = Settings.barOpacity;
                }
            }
        }

        Group {
            title: "Icons"

            SliderRow {
                label: "Icon size"
                value: Settings.iconSize
                minimum: 10
                maximum: 24
                suffix: "px"
                onAdjusted: newValue => Settings.iconSize = Math.round(newValue)
            }

            SliderRow {
                label: "Icon padding"
                value: Settings.iconPadding
                minimum: 0
                maximum: 12
                suffix: "px"
                onAdjusted: newValue => Settings.iconPadding = Math.round(newValue)
            }

            SliderRow {
                label: "Module spacing"
                value: Settings.moduleSpacing
                minimum: 0
                maximum: 16
                suffix: "px"
                onAdjusted: newValue => Settings.moduleSpacing = Math.round(newValue)
            }

            SliderRow {
                label: "Workspace spacing"
                value: Settings.workspaceSpacing
                minimum: 2
                maximum: 28
                suffix: "px"
                onAdjusted: newValue => Settings.workspaceSpacing = Math.round(newValue)
            }
        }

        Group {
            title: "Accent and hover"

            SwatchRow {
                label: "Accent colour"
                options: root.accentColors
                current: Settings.accentColor
                onPicked: value => Settings.accentColor = value
            }

            SliderRow {
                label: "Hover opacity"
                value: Settings.hoverOpacity
                minimum: 0
                maximum: 0.6
                decimals: 2
                onAdjusted: newValue => Settings.hoverOpacity = newValue
            }

            SliderRow {
                label: "Hover corner radius"
                value: Settings.hoverRadius
                minimum: 0
                maximum: 20
                suffix: "px"
                onAdjusted: newValue => Settings.hoverRadius = Math.round(newValue)
            }
        }

        Group {
            title: "Clock and calendar"

            ToggleRow {
                label: "Show seconds"
                checked: Settings.clockShowSeconds
                onToggled: Settings.clockShowSeconds = !Settings.clockShowSeconds
            }

            ToggleRow {
                label: "12 hour clock"
                checked: Settings.clockUse12Hour
                onToggled: Settings.clockUse12Hour = !Settings.clockUse12Hour
            }

            ToggleRow {
                label: "Minute progress line"
                checked: Settings.clockShowProgress
                onToggled: Settings.clockShowProgress = !Settings.clockShowProgress
            }

            ToggleRow {
                label: "Calendar opens on year view"
                checked: Settings.calendarYearView
                onToggled: Settings.calendarYearView = !Settings.calendarYearView
            }
        }

        ButtonRow {
            label: "Restore defaults"
            onTriggered: Settings.restoreDefaults()
        }
    }
}
