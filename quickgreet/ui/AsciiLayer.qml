import QtQuick
import qs.config
import "ascii.js" as Ascii

// The animated layer between the wallpaper and the card.
Item {
    id: root

    readonly property var effect: Config.entry(Ascii.effects, Config.animation)
    readonly property var palette: Config.ramp

    // Whole pixels, so the atlas and the screen line up texel for texel and the glyphs stay sharp.
    readonly property int cellWidth: Math.ceil(em.advanceWidth)
    readonly property int cellHeight: Math.ceil(metrics.height)
    readonly property int cols: root.cellWidth > 0 ? Math.ceil(root.width / root.cellWidth) : 0
    readonly property int rows: root.cellHeight > 0 ? Math.ceil(root.height / root.cellHeight) : 0

    property var grid: null

    opacity: Config.animationOpacity

    // A new grid whenever the effect or the size changes, once per burst of changes.
    function reset() {
        canvas.image = null;
        if (!root.effect || root.cols < 1 || root.rows < 1) {
            root.grid = null;
            return;
        }
        const g = Ascii.grid(root.cols, root.rows, root.cellWidth, root.cellHeight);
        g.effect = root.effect;
        g.effect.init(g);
        root.grid = g;
    }

    onEffectChanged: Qt.callLater(root.reset)
    onColsChanged: Qt.callLater(root.reset)
    onRowsChanged: Qt.callLater(root.reset)

    FontMetrics {
        id: metrics

        font.family: Config.monoFamily
        font.pixelSize: Config.cellSize
    }

    // A property rather than metrics.advanceWidth("M").
    TextMetrics {
        id: em

        font: metrics.font
        text: "M"
    }

    // Speed is how often a frame is drawn rather than how far each one moves.
    Timer {
        interval: Math.max(16, Math.round(100000 / ((root.effect ? root.effect.fps : 20) * Config.animationSpeed)))
        repeat: true
        running: root.grid !== null && canvas.available
        triggeredOnStart: true

        // The grid's own effect rather than the one now chosen.
        onTriggered: {
            root.grid.effect.step(root.grid);
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas

        property var image: null

        width: root.cols
        height: root.rows
        visible: false
        smooth: false
        renderStrategy: Canvas.Immediate

        onPaint: {
            if (!root.grid)
                return;
            const context = canvas.getContext("2d");
            if (!canvas.image)
                canvas.image = context.createImageData(root.cols, root.rows);
            Ascii.paint(root.grid, canvas.image.data);

            // drawImage rather than putImageData, which draws nothing at all in Qt 6.11.
            context.drawImage(canvas.image, 0, 0);
        }
    }

    Row {
        id: atlas

        Repeater {
            model: Ascii.charset.length

            Text {
                required property int index

                width: root.cellWidth
                height: root.cellHeight

                // A glyph the font lacks comes from a fallback that may be wider, and would spill into the next slot.
                clip: true
                text: Ascii.charset[index]
                color: "white"
                font: metrics.font
                textFormat: Text.PlainText
                lineHeightMode: Text.FixedHeight
                lineHeight: root.cellHeight
            }
        }
    }

    ShaderEffectSource {
        id: atlasTexture

        sourceItem: atlas
        hideSource: true
        smooth: false
    }

    ShaderEffect {
        readonly property var grid: canvas
        readonly property var atlas: atlasTexture
        readonly property size cells: Qt.size(root.cols, root.rows)
        readonly property size cellSize: Qt.size(root.cellWidth, root.cellHeight)
        readonly property size area: Qt.size(width, height)
        readonly property real glyphs: Ascii.charset.length
        readonly property color color0: root.palette[0]
        readonly property color color1: root.palette[1]
        readonly property color color2: root.palette[2]
        readonly property color color3: root.palette[3]
        readonly property color color4: root.palette[4]
        readonly property color color5: root.palette[5]

        anchors.fill: parent
        visible: root.grid !== null
        fragmentShader: "ascii.frag.qsb"
    }
}
