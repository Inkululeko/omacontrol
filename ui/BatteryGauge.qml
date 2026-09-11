import QtQuick
import qs.Commons
import "." as Local

// The battery drawn rather than set in a font: a glyph can only step through
// ten levels and can only be one colour, and this is the one thing on the
// Power page that should be readable from across the desk.
//
// Lying down, because that is the shape a battery is drawn in everywhere a
// picture of one is meant to be read as a gauge — the fill then runs the way
// a bar does, left to right, and the level is a length rather than a glyph to
// be recognised.
Item {
  id: gauge

  // 0 to 1.
  property real level: 0
  property bool charging: false
  property color fill: Local.Palette.accent

  implicitWidth: Style.space(74)
  implicitHeight: Style.space(34)

  readonly property real border: Math.max(1, Style.space(2))
  readonly property real inset: gauge.border + Math.max(1, Style.space(1.5))

  // While charging the fill sweeps from empty up to where the charge actually
  // is, over and over: the same thing every phone does, and the only way a
  // still picture of a battery can say that something is happening to it.
  property real sweep: 0
  readonly property real shown: charging
    ? Math.max(0, Math.min(1, sweep)) : Math.max(0, Math.min(1, level))

  SequentialAnimation on sweep {
    running: gauge.charging
    loops: Animation.Infinite
    alwaysRunToEnd: false
    NumberAnimation { from: 0; to: gauge.level; duration: 1400; easing.type: Easing.InOutQuad }
    PauseAnimation { duration: 600 }
  }

  Rectangle {
    id: body
    width: parent.width - cap.width
    height: parent.height
    radius: Math.max(Style.space(7), Style.cornerRadius)
    color: "transparent"
    border.width: gauge.border
    border.color: gauge.fill

    Rectangle {
      x: gauge.inset
      y: gauge.inset
      height: parent.height - gauge.inset * 2
      // Never a sliver of colour with nothing in it: below a few percent the
      // fill is rounder than it is wide and reads as a dot rather than as an
      // amount, so it keeps its own height as a minimum.
      width: Math.max(gauge.shown > 0 ? height : 0,
                      (parent.width - gauge.inset * 2) * gauge.shown)
      radius: Math.max(Style.space(3), Style.cornerRadius / 2)
      color: gauge.fill

      Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }
  }

  // The nub on the end, which is what makes the rounded rectangle a battery
  // rather than a progress bar.
  Rectangle {
    id: cap
    anchors.left: body.right
    anchors.verticalCenter: body.verticalCenter
    width: Math.max(2, Style.space(3))
    height: parent.height * 0.42
    radius: width / 2
    color: gauge.fill
  }
}
