pragma ComponentBehavior: Bound

import QtQuick
import "root:/config"
import "root:/components"

Rectangle {
    id: picker

    property string value: ""

    property real hue: 0
    property real saturation: 0
    property real brightness: 0

    // What this last sent, so its own change coming back as `value` does not move the cursors.
    property string sent: ""

    signal picked(string value)

    function load(): void {
        const color = Qt.color(picker.value !== "" ? picker.value : "#000000");

        // A grey has no hue of its own; the strip stays where it was rather than jumping to red.
        if (color.hsvHue >= 0)
            picker.hue = color.hsvHue;
        picker.saturation = color.hsvSaturation;
        picker.brightness = color.hsvValue;
        hexField.text = color.toString();
    }

    function send(): void {
        picker.sent = Qt.hsva(picker.hue, picker.saturation, picker.brightness, 1).toString();
        hexField.text = picker.sent;
        picker.picked(picker.sent);
    }

    function clamp(value: real): real {
        return Math.min(Math.max(value, 0), 1);
    }

    onValueChanged: {
        if (picker.value.toLowerCase() !== picker.sent)
            picker.load();
    }
    Component.onCompleted: picker.load()

    implicitHeight: pickerColumn.implicitHeight + 24
    radius: Theme.radius
    color: Theme.fillTrack

    Column {
        id: pickerColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        Rectangle {
            id: field

            width: parent.width
            height: 120
            radius: Theme.radius
            color: Qt.hsva(picker.hue, 1, 1, 1)

            activeFocusOnTab: true
            Keys.onLeftPressed: {
                picker.saturation = picker.clamp(picker.saturation - 0.02);
                picker.send();
            }
            Keys.onRightPressed: {
                picker.saturation = picker.clamp(picker.saturation + 0.02);
                picker.send();
            }
            Keys.onUpPressed: {
                picker.brightness = picker.clamp(picker.brightness + 0.02);
                picker.send();
            }
            Keys.onDownPressed: {
                picker.brightness = picker.clamp(picker.brightness - 0.02);
                picker.send();
            }

            FocusRing {}

            // White fading out to the right, then black fading in towards the bottom, over the pure hue.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "#ffffffff"
                    }
                    GradientStop {
                        position: 1
                        color: "#00ffffff"
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#00000000"
                    }
                    GradientStop {
                        position: 1
                        color: "#ff000000"
                    }
                }
            }

            // Filled with the colour itself inside a white ring and a dark one.
            Rectangle {
                x: picker.saturation * field.width - width / 2
                y: (1 - picker.brightness) * field.height - height / 2
                z: 1
                width: 18
                height: 18
                radius: 9
                color: Qt.hsva(picker.hue, picker.saturation, picker.brightness, 1)
                border.width: 1
                border.color: "#000000"

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: "#ffffff"
                }
            }

            MouseArea {
                function take(mouse: var): void {
                    picker.saturation = picker.clamp((mouse.x - 9) / field.width);
                    picker.brightness = 1 - picker.clamp((mouse.y - 9) / field.height);
                    picker.send();
                }

                anchors.fill: parent
                anchors.margins: -9
                cursorShape: Qt.CrossCursor
                preventStealing: true
                onPressed: mouse => take(mouse)
                onPositionChanged: mouse => take(mouse)
            }
        }

        Rectangle {
            id: strip

            width: parent.width
            height: 14
            radius: Theme.radius

            activeFocusOnTab: true
            Keys.onLeftPressed: {
                picker.hue = (picker.hue + 359 / 360) % 1;
                picker.send();
            }
            Keys.onRightPressed: {
                picker.hue = (picker.hue + 1 / 360) % 1;
                picker.send();
            }

            FocusRing {}

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "#ff0000"
                }
                GradientStop {
                    position: 1 / 6
                    color: "#ffff00"
                }
                GradientStop {
                    position: 2 / 6
                    color: "#00ff00"
                }
                GradientStop {
                    position: 3 / 6
                    color: "#00ffff"
                }
                GradientStop {
                    position: 4 / 6
                    color: "#0000ff"
                }
                GradientStop {
                    position: 5 / 6
                    color: "#ff00ff"
                }
                GradientStop {
                    position: 1
                    color: "#ff0000"
                }
            }

            Rectangle {
                x: picker.hue * strip.width - width / 2
                z: 1
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: strip.height + 8
                radius: 3
                color: Qt.hsva(picker.hue, 1, 1, 1)
                border.width: 2
                border.color: "#ffffff"
            }

            MouseArea {
                function take(mouse: var): void {
                    // Short of 1, which is red again, so dragging off the right end stays on magenta.
                    picker.hue = Math.min(picker.clamp(mouse.x / strip.width), 0.999);
                    picker.send();
                }

                anchors.fill: parent
                anchors.topMargin: -6
                anchors.bottomMargin: -6
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onPressed: mouse => take(mouse)
                onPositionChanged: mouse => take(mouse)
            }
        }

        Item {
            width: parent.width
            height: 30

            Rectangle {
                id: preview

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 24
                radius: Theme.radius
                color: picker.value !== "" ? picker.value : "#000000"
                border.width: 1
                border.color: Theme.cardBorder
            }

            // Taken on Enter or on leaving the field, with or without the #, and only once it is six hex digits.
            TextField {
                id: hexField

                anchors.left: preview.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 130

                placeholder: "#rrggbb"

                onEditingFinished: {
                    const match = hexField.text.trim().match(/^#?([0-9a-fA-F]{6})$/);
                    if (!match) {
                        hexField.text = picker.value;
                        return;
                    }
                    picker.sent = "#" + match[1].toLowerCase();
                    picker.picked(picker.sent);
                    picker.load();
                }
            }
        }
    }
}
