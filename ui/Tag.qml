import QtQuick
import qs.Commons
import "." as Local

// A pill that only reports — how many settings have been changed, that SMART
// passed. It looks like a Chip with the affordances taken away on purpose:
// same size and shape, filled rather than outlined, and nothing happens when
// you press it, because nothing is meant to.
Rectangle {
  id: tag
  property string text: ""
  // Accented when the fact is about something the reader did, plain when it is
  // something the machine is reporting.
  property bool accented: true

  implicitWidth: label.implicitWidth + Style.space(18)
  implicitHeight: Style.space(20)
  radius: Local.Palette.pillRadius
  color: tag.accented ? Local.Palette.tint(0.16) : Local.Palette.shade(0.08)

  Text {
    id: label
    anchors.centerIn: parent
    text: tag.text
    color: tag.accented ? Local.Palette.accent : Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
