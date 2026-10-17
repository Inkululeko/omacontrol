import QtQuick
import qs.Commons
import "." as Local

// One glyph, centred by its ink rather than by its advance.
//
// Icon-font glyphs share neither an advance width nor an ink width: a wifi arc
// is 10 px of ink, a speaker 20, and each sits at a different offset inside
// its own advance box. Setting a width on the Text and asking for AlignHCenter
// centres the *advance*, and when the advance is as wide as the column — which
// it is for most of these — that does nothing at all: every glyph lands hard
// against the left edge and the column reads as ragged as it did before.
//
// TextMetrics.tightBoundingRect is the smallest rectangle holding the drawn
// pixels, so shifting by it puts the ink itself in the middle of the box. That
// is what makes a column of unrelated glyphs look like a column.
Item {
  id: icon

  property string glyph: ""
  property color color: Local.Palette.foreground
  property real size: Style.font.body

  implicitWidth: Style.space(20)
  implicitHeight: Style.space(20)

  TextMetrics {
    id: metrics
    font.family: Local.Palette.fontFamily
    font.pixelSize: icon.size
    text: icon.glyph
  }

  Text {
    textFormat: Text.PlainText
    // Horizontally by the ink, vertically by the line. tightBoundingRect's y
    // is not measured from the item's top, so shifting by it drops every
    // glyph below its own label — which is exactly what it did.
    x: (icon.width - metrics.tightBoundingRect.width) / 2 - metrics.tightBoundingRect.x
    anchors.verticalCenter: parent.verticalCenter
    text: icon.glyph
    color: icon.color
    font.family: Local.Palette.fontFamily
    font.pixelSize: icon.size
  }
}
