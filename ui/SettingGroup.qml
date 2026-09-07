import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

Column {
  id: group
  property string title: ""
  property string note: ""
  default property alias content: groupContent.data

  // The padding inside the card. Rows read it so a cursor band can run the
  // full width of the card rather than stopping short of its edges.
  readonly property real pad: Style.space(14)

  width: parent ? parent.width : 0
  spacing: Style.space(6)

  // A group whose rows have all been filtered away goes with them, heading
  // and all, or the page fills with headings over nothing.
  property var nav: null
  Component.onCompleted: {
    var node = group.parent
    while (node) {
      if (node.searching !== undefined) { group.nav = node; break }
      if (node.app !== undefined && node.app !== null && node.app.searching !== undefined) {
        group.nav = node.app
        break
      }
      node = node.parent
    }
  }

  readonly property bool searchEmpty: {
    if (!group.nav || group.nav.searching !== true) return false
    var kids = groupContent.children
    for (var i = 0; i < kids.length; i++) {
      // A Repeater sits among the rows it made, visible and no height at all.
      // Counting it as content left every heading standing over an emptied
      // group — and a Repeater's implicit height is zero too, so the test
      // still passes over it.
      //
      // `implicitHeight` and not `height`: a child's laid-out height is zero
      // while its group is hidden, and the group is hidden by this very
      // property, which is a loop. What a row *asks* for does not depend on
      // whether anyone is showing it.
      if (kids[i].visible === true && kids[i].implicitHeight > 0) return false
    }
    return true
  }

  visible: !searchEmpty

  Text {
    visible: group.title !== ""
    text: group.title
    color: Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  Text {
    visible: group.note !== ""
    width: group.width
    text: group.note
    wrapMode: Text.WordWrap
    color: Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
    bottomPadding: Style.space(4)
  }

  // What belongs to a heading used to be stepped in from it. A card says the
  // same thing and says it better: an indent has to be compared against the
  // heading above to be read at all, while an edge is visible on its own, and
  // it holds even where the rows are a table or a list rather than settings.
  Rectangle {
    width: group.width
    implicitHeight: groupContent.implicitHeight + group.pad * 2
    radius: Local.Palette.cardRadius
    color: Local.Palette.card
    border.width: Style.spacing.hairline
    border.color: Local.Palette.divider

    Column {
      id: groupContent
      x: group.pad
      y: group.pad
      width: group.width - group.pad * 2
      spacing: Style.space(12)
    }
  }
}
