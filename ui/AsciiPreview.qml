import QtQuick
import qs.Commons
import "." as Local

// Branding is ASCII, however it was made — typed, or transcoded from an
// image — so the thing itself is the only honest preview of it. Drawn at
// whatever size fits rather than at a chosen one: the art is between fifty
// and eighty columns wide depending on where it came from, and a fixed size
// would clip one and strand the other in the middle of an empty card.
Rectangle {
  id: preview
  property string text: ""

  width: parent ? parent.width : 0
  height: Style.space(150)
  radius: Local.Palette.cardRadius
  color: Local.Palette.card
  border.width: Style.spacing.hairline
  border.color: Local.Palette.divider

  Text {
    textFormat: Text.PlainText
    anchors.fill: parent
    anchors.margins: Style.space(10)
    text: preview.text
    color: Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.title
    minimumPixelSize: 1
    fontSizeMode: Text.Fit
    wrapMode: Text.NoWrap
    // Block-drawing rows are meant to touch; the gap a text line-height
    // leaves between them breaks the art into stripes.
    lineHeight: 1.0
    lineHeightMode: Text.ProportionalHeight
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
