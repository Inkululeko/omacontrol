import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A row that is entirely a link: the whole width is the target, with whatever
// the source calls the date at the far end. For lists where every row goes
// somewhere and none of them has a second thing you could do to it — a button
// per row would be one button per row doing what the row already does.
NavRow {
  id: linkRow
  property string value: ""
  signal triggered()

  navKeys: [{ key: "↵", label: "Open" }]
  onNavActivate: linkRow.triggered()

  implicitHeight: Math.max(title.implicitHeight, stamp.implicitHeight) + Style.space(10)

  Text {
    id: title
    anchors.left: parent.left
    anchors.right: stamp.left
    anchors.rightMargin: Style.space(14)
    anchors.verticalCenter: parent.verticalCenter
    text: linkRow.label
    elide: Text.ElideRight
    color: mouse.containsMouse ? Local.Palette.accent : Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
    font.underline: mouse.containsMouse
  }

  Text {
    id: stamp
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: linkRow.value
    color: Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: linkRow.triggered()
  }
}
