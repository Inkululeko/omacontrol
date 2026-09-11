import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

Column {
  id: group
  property string title: ""
  property string note: ""
  default property alias content: groupContent.data

  // The gap between rows. A group that is a *list* — devices, networks,
  // bindings — sets it tighter: the rows belong to one another there, and
  // settings-sized air between them breaks the list into fragments.
  property real rowSpacing: Style.space(20)

  // Settings do not sit in a card: down a page of eight groups the edges were
  // more chrome than structure, and a heading large enough to be read as one
  // separates just as well. A card is for a group that is one *thing* being
  // reported on — the connection you are on, what needs attention — where the
  // edge says where the thing stops.
  property bool framed: false

  // The padding inside the card. Rows read it so a cursor band can run the
  // full width of the card rather than stopping short of its edges.
  readonly property real pad: framed ? Style.space(14) : 0

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
      // Content that is not a row — a table, a chart, a row of chips — has to
      // state an `implicitHeight` to be counted. Everything that computes its
      // own size does (Row, Column, Grid, a Layout); a bare Item given only a
      // `height` does not, and is read as nothing.
      if (kids[i].searchHidden !== true && kids[i].implicitHeight > 0) return false
    }
    return true
  }

  visible: !searchEmpty

  // With no card edge between groups, the space above a heading is what
  // separates one from the last.
  Text {
    visible: group.title !== ""
    topPadding: Style.space(8)
    text: group.title
    color: Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.heading
    font.bold: true
  }

  // A rule under the heading, so a group reads as a band of the page rather
  // than as a heading that happens to have rows after it.
  Rectangle {
    visible: group.title !== ""
    width: group.width
    height: Style.spacing.hairline
    color: Local.Palette.divider
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

  // The air a note leaves under the rule is what the band wants; a group
  // without one had its first row up against the line and read as tighter
  // than its neighbour for no reason the page could show.
  Item {
    visible: group.title !== "" && group.note === ""
    width: group.width
    height: Style.space(4)
  }

  Rectangle {
    width: group.width
    implicitHeight: groupContent.implicitHeight + group.pad * 2
    radius: group.framed ? Local.Palette.cardRadius : 0
    color: group.framed ? Local.Palette.card : "transparent"
    border.width: group.framed ? Style.spacing.hairline : 0
    border.color: Local.Palette.divider

    Column {
      id: groupContent
      x: group.pad
      y: group.pad
      width: group.width - group.pad * 2
      spacing: group.rowSpacing
    }
  }
}
