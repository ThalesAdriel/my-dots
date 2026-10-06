import QtQuick
import qs.config

// The border round the login card, laid over it.
Item {
    id: root

    readonly property var glyphs: ({
            corners: "┌┐└┘  ",
            dashed: "┌┐└┘╌╎",
            rounded: "╭╮╰╯─│",
            double: "╔╗╚╝═║",
            ascii: "++++-|"
        })
    readonly property string set: Config.entry(root.glyphs, Config.border) || ""

    Rectangle {
        visible: Config.border === "brackets"
        anchors.right: parent.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: Math.round(parent.height * 0.8)
        color: Config.line
    }

    Rectangle {
        visible: Config.border === "brackets"
        anchors.left: parent.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 3
        height: Math.round(parent.height * 0.8)
        color: Config.line
    }

    // Up to a cell wider and taller than the card, so the lines.
    Text {
        id: frame

        readonly property int cols: Math.ceil(root.width / Math.max(1, em.advanceWidth)) + 1
        readonly property int rows: Math.ceil(root.height / Math.ceil(metrics.height)) + 1

        anchors.centerIn: parent

        visible: root.set !== ""
        color: Config.line
        font: metrics.font
        textFormat: Text.PlainText
        lineHeightMode: Text.FixedHeight
        lineHeight: Math.ceil(metrics.height)

        text: {
            const s = root.set;
            if (s === "")
                return "";
            const inner = Math.max(0, frame.cols - 2);
            const lines = [s[0] + s[4].repeat(inner) + s[1]];
            for (let i = 0; i < frame.rows - 2; i++)
                lines.push(s[5] + " ".repeat(inner) + s[5]);
            lines.push(s[2] + s[4].repeat(inner) + s[3]);
            return lines.join("\n");
        }
    }

    FontMetrics {
        id: metrics

        font.family: Config.monoFamily
        font.pixelSize: 16
    }

    TextMetrics {
        id: em

        font: metrics.font
        text: "M"
    }
}
