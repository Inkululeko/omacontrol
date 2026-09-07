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
      // Asked of the row itself, never of its `visible`. QML's `visible` is
      // *effective* visibility — false whenever any ancestor is hidden — so a
      // group deciding its own `visible` from its children's `visible` is
      // reading a value that depends on the answer. That is the binding loop,
      // and it was here from the start; it only ever showed up as a warning
      // because Qt breaks the cycle itself and carries on with whichever value
      // it had.
      //
      // `searchHidden` is the row's own verdict on the search term and depends
      // on nothing above it. A child that is not a row does not have one,
      // which is the right answer for a table or a button: they are content.
      //
      // `implicitHeight` and not `height` for the same reason: a laid-out
      // height is zero while the group is hidden. A Repeater asks for no
      // height either way, which is what keeps it from counting as content.
      if (kids[i].searchHidden !== true && kids[i].implicitHeight > 0) return false
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
