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
  // Unread rows carry a star. It is both the mark and the way to clear it:
  // there is nothing else a reader would want to do to a star, so making it
  // the button saves a second control that would mean the same thing.
  property bool unread: false
  signal triggered()
  signal starred()

  // Not Space: the window routes Space and Enter to the same signal, so a
  // legend offering "Space — Mark read" would open the article instead. The
  // step keys are the ones a row can tell apart.
  navKeys: linkRow.unread
    ? [{ key: "↵", label: "Open" }, { key: "→", label: "Mark read" }]
    : [{ key: "↵", label: "Open" }]
  onNavActivate: linkRow.triggered()
  onNavStep: function(delta) { if (delta > 0 && linkRow.unread) linkRow.starred() }

  implicitHeight: Math.max(title.implicitHeight, stamp.implicitHeight) + Style.space(10)

  // Present but empty on a read row rather than absent, so the headlines all
  // start in the same place — a column of titles that shifts by ten pixels
  // depending on whether you have read them is worse than a wasted indent.
  Text {
    id: star
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(16)
    text: linkRow.unread ? "" : ""
    color: starMouse.containsMouse ? Local.Palette.foreground : Local.Palette.accent
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption

    MouseArea {
      id: starMouse
      anchors.fill: parent
      anchors.margins: -Style.space(4)
      enabled: linkRow.unread
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: linkRow.starred()
    }
  }

  Text {
    id: title
    anchors.left: star.right
    anchors.right: stamp.left
    anchors.rightMargin: Style.space(14)
    anchors.verticalCenter: parent.verticalCenter
    text: linkRow.label
    elide: Text.ElideRight
    color: mouse.containsMouse ? Local.Palette.accent : Local.Palette.foreground
    // An unread headline is the only bold thing in the list, which is what
    // makes "two new" legible without counting stars.
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.body
    font.bold: linkRow.unread
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
    // From the title onward. Filling the whole row would put this over the
    // star and take its clicks, since the later sibling wins.
    anchors.left: title.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: linkRow.triggered()
  }
}
