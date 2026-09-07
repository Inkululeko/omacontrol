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

  // The one line of relief: a cap lit from above reads as a key without a
  // border, and a border here would double the count of lines in the bar.
  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Style.spacing.hairline
    radius: parent.radius
    color: Local.Palette.shade(0.14)
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: cap.key
    color: Local.Palette.shade(0.8)
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
