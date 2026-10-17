import QtQuick
import qs.Commons
import "." as Local

// A single key, drawn as the key. The legend along the foot of the window used
// to be plain text on the grounds that a row of boxes pulls the eye off the
// settings; the design puts the caps back, and they hold up because they are
// small, low-contrast and all the same size — the row reads as one band of
// chrome rather than as seven separate objects.
Rectangle {
  id: cap
  property string key: ""

  implicitWidth: Math.max(Style.space(18), label.implicitWidth + Style.space(10))
  implicitHeight: Style.space(18)
  radius: Local.Palette.chipRadius
  color: Local.Palette.shade(0.11)

  // Flat, with no edge drawn under it. There was a hairline "lit from above"
  // along the bottom, and a line one pixel tall cannot follow the cap's
  // rounded corners: it ran straight out past them and read as an underline.

  Text {
    id: label
    textFormat: Text.PlainText
    anchors.centerIn: parent
    text: cap.key
    color: Local.Palette.shade(0.8)
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
