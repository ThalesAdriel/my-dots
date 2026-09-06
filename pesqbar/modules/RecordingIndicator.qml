import QtQuick
import "root:/config"
import "root:/components"
import "root:/services"

// The screen capture dot, the way macOS puts one in the menu bar: on screen
// only while something is recording, and doing nothing but saying so. Hovering
// it names the recording and how long it has been going; there is no action
// behind it, so a stray click cannot end a take.
BarButton {
    id: root

    visible: Recording.active

    IconStack {
        IconText {
            id: dot

            anchors.centerIn: parent
            text: Glyphs.circle
            color: Theme.urgent
            font.pixelSize: Theme.iconSize - 2

            // Slow enough to read as a state rather than as an alarm, and only
            // running while the dot is on screen.
            SequentialAnimation on opacity {
                running: Recording.active
                loops: Animation.Infinite
                alwaysRunToEnd: false

                NumberAnimation {
                    from: 1.0
                    to: 0.35
                    duration: 1100
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.35
                    to: 1.0
                    duration: 1100
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    BarTooltip {
        anchorItem: root
        shown: root.containsMouse && Recording.active
        text: "Recording the screen, " + Recording.elapsedLabel
    }
}
