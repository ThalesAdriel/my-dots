import QtQuick
import QtQuick.Shapes

// The quarter circle that flares a surface out into the edge it sits against: placed just outside the surface and filled with its colour, the two read as one shape and the background corner between them comes out rounded.
Shape {
    id: root

    property int size: 0
    property color fillColor: "black"

    // The corner of this item the quarter circle is centred on, which is also the corner of the surface it flares out from.
    property bool centreRight: true
    property bool centreBottom: false

    readonly property real centreX: root.centreRight ? root.size : 0
    readonly property real centreY: root.centreBottom ? root.size : 0

    implicitWidth: root.size
    implicitHeight: root.size
    width: root.size
    height: root.size
    visible: root.size > 0

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.fillColor
        strokeColor: "transparent"

        startX: root.size - root.centreX
        startY: root.centreY

        PathLine {
            x: root.centreX
            y: root.centreY
        }

        PathLine {
            x: root.centreX
            y: root.size - root.centreY
        }

        PathArc {
            x: root.size - root.centreX
            y: root.centreY
            radiusX: root.size
            radiusY: root.size
            direction: root.centreRight !== root.centreBottom ? PathArc.Counterclockwise : PathArc.Clockwise
        }
    }
}
