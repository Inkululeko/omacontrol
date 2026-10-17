import QtQuick
import qs.Commons
import "." as Local

// An outlined pill that does something the moment it is clicked — "Undo all",
// a sort order, a filter. Distinct from the kit's Button, which carries the
// weight of a form control; a chip is the lightest thing that can still be
// pressed, and pages use rows of them where a dropdown would hide the choices.
Rectangle {
  id: chip
  property string text: ""
  property bool on: false
  signal clicked()

  implicitWidth: label.implicitWidth + Style.space(22)
  implicitHeight: Style.space(22)
  radius: Local.Palette.pillRadius
  color: chip.on ? Local.Palette.accent
                 : (mouse.containsMouse ? Local.Palette.tint(0.14) : "transparent")
  border.width: chip.on ? 0 : Style.spacing.hairline
  border.color: mouse.containsMouse ? Local.Palette.tint(0.5) : Local.Palette.shade(0.28)

  Text {
    id: label
    textFormat: Text.PlainText
    anchors.centerIn: parent
    text: chip.text
    color: chip.on ? Local.Palette.onAccent : Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: chip.clicked()
  }
}
