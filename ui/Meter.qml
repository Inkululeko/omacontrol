import QtQuick
import qs.Commons
import "." as Local

// How full something is, as a bar. Read-only: a slider you can drag says the
// value is yours to set, and none of the things this draws — a partition, a
// core, a process's share of the memory — is.
Item {
  id: meter
  // 0 to 1. Anything outside that is clamped rather than drawn past the end.
  property real value: 0
  property color fill: Local.Palette.accent
  // The one reading worth a colour of its own: nearly full, on something
  // where full is a problem.
  property bool warn: false

  implicitWidth: Style.space(120)
  implicitHeight: Style.space(7)

  Rectangle {
    id: track
    anchors.fill: parent
    radius: height / 2
    color: Local.Palette.shade(0.14)

    Rectangle {
      height: parent.height
      radius: parent.radius
      width: Math.max(0, Math.min(1, meter.value)) * parent.width
      color: meter.warn ? Local.Palette.urgent : meter.fill
    }
  }
}
