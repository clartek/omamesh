import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root
  property real iconSize: Style.font.icon
  property color color: Color.foreground

  width: Math.round(iconSize * 1.36)
  height: Math.round(iconSize)
  implicitWidth: width
  implicitHeight: height

  readonly property real cx: width / 2
  readonly property real cy: height / 2
  readonly property real unit: height / 70.0
  readonly property real rDot: 8.5 * unit
  readonly property real r1: 24.0 * unit
  readonly property real r2: 44.0 * unit
  readonly property real strokeW: Math.max(1.25, 7.5 * unit)
  readonly property real c45: 0.70710678

  Shape {
    anchors.fill: parent
    antialiasing: true
    layer.enabled: true
    layer.samples: 4

    // Center dot
    ShapePath {
      fillColor: root.color
      strokeColor: "transparent"
      startX: root.cx + root.rDot
      startY: root.cy
      PathArc {
        x: root.cx - root.rDot
        y: root.cy
        radiusX: root.rDot
        radiusY: root.rDot
        useLargeArc: true
      }
      PathArc {
        x: root.cx + root.rDot
        y: root.cy
        radiusX: root.rDot
        radiusY: root.rDot
        useLargeArc: true
      }
    }

    // Inner right arc
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeW
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.cx + root.r1 * root.c45
      startY: root.cy - root.r1 * root.c45
      PathArc {
        x: root.cx + root.r1 * root.c45
        y: root.cy + root.r1 * root.c45
        radiusX: root.r1
        radiusY: root.r1
        direction: PathArc.Clockwise
      }
    }

    // Inner left arc
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeW
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.cx - root.r1 * root.c45
      startY: root.cy - root.r1 * root.c45
      PathArc {
        x: root.cx - root.r1 * root.c45
        y: root.cy + root.r1 * root.c45
        radiusX: root.r1
        radiusY: root.r1
        direction: PathArc.Counterclockwise
      }
    }

    // Outer right arc
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeW
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.cx + root.r2 * root.c45
      startY: root.cy - root.r2 * root.c45
      PathArc {
        x: root.cx + root.r2 * root.c45
        y: root.cy + root.r2 * root.c45
        radiusX: root.r2
        radiusY: root.r2
        direction: PathArc.Clockwise
      }
    }

    // Outer left arc
    ShapePath {
      strokeColor: root.color
      strokeWidth: root.strokeW
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.cx - root.r2 * root.c45
      startY: root.cy - root.r2 * root.c45
      PathArc {
        x: root.cx - root.r2 * root.c45
        y: root.cy + root.r2 * root.c45
        radiusX: root.r2
        radiusY: root.r2
        direction: PathArc.Counterclockwise
      }
    }
  }
}
