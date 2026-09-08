import QtQuick
import qs.Commons
import "." as Local

// The tinted square in front of a sidebar row. It is what lets someone find
// "the network one" without reading the list: eight tints, one per cluster,
// so the rows carry the grouping even after a search has pulled the gaps
// between clusters apart.
Rectangle {
  id: square
  property string glyph: ""
  property color tint: Local.Palette.accent
  // On the open row the square would be accent-on-accent, which is a smudge.
  // It goes to the row's own text colour instead and keeps only its shape.
  property bool inverted: false

  implicitWidth: Style.space(24)
  implicitHeight: Style.space(24)
  radius: Local.Palette.iconRadius
  color: square.inverted ? Local.Palette.onAccentWash(0.20) : square.tint

  Text {
    anchors.centerIn: parent
    text: square.glyph
    color: Local.Palette.onAccent
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.iconSmall
  }
}
