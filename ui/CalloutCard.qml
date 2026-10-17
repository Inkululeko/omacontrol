import QtQuick
import qs.Commons
import "." as Local

// One fact the reader should meet before the list under it — a kernel
// arriving, a new Omarchy. A box rather than a row because it is not one of
// the things it sits above: given a row's shape it read as the first line of
// the table, which is exactly where it was trying not to be.
//
// It carries the reading and the fact and nothing else. The version is the
// part the reader cannot know; what a kernel costs at the next boot is the
// part they already do, and a sentence saying it again was there on every
// visit after the first.
//
// The tone is a status rather than a colour. `Palette.caution` is the theme's
// own red with the hue moved, so a yellow box is that theme's yellow.
Rectangle {
  id: card

  property string glyph: ""
  property string label: ""
  property string detail: ""
  property color tone: Local.Palette.caution

  implicitHeight: Math.max(body.implicitHeight, mark.implicitHeight) + Style.space(28)
  radius: Local.Palette.cardRadius
  color: Local.Palette.washOf(card.tone, 0.10)
  border.width: Style.spacing.hairline
  border.color: Local.Palette.washOf(card.tone, 0.38)

  // The search takes what does not match off the page rather than dimming it,
  // so a box that sat through every search would read as the filter being
  // broken. Found by walking up, the way a row finds it: nothing between a
  // page and its boxes knows about the window.
  property var nav: null
  property string groupTitle: ""
  Component.onCompleted: {
    var node = card.parent
    while (node) {
      if (card.groupTitle === "" && node.searchEmpty !== undefined)
        card.groupTitle = String(node.title || "")
      if (node.searching !== undefined) { card.nav = node; break }
      if (node.app !== undefined && node.app !== null && node.app.searching !== undefined) {
        card.nav = node.app
        break
      }
      node = node.parent
    }
  }

  readonly property bool searchHidden: card.nav !== null && card.nav.searching === true
    && !card.nav.rowMatches(card.label, card.detail, card.groupTitle)
  visible: !searchHidden

  // Placed rather than anchored: a child anchored to a parent that takes its
  // height from that child is the binding loop this window has paid for
  // before, and both of these are measured from their own text.
  Text {
    id: mark
    textFormat: Text.PlainText
    x: Style.space(14)
    y: Style.space(14)
    text: card.glyph
    color: card.tone
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.iconLarge
  }

  Column {
    id: body
    x: mark.x + mark.width + Style.space(12)
    y: Style.space(14)
    width: card.width - x - Style.space(14)
    spacing: Style.space(3)

    Text {
      textFormat: Text.PlainText
      text: card.label
      color: card.tone
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.capitalization: Font.AllUppercase
      font.letterSpacing: Style.space(1)
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: card.detail
      elide: Text.ElideRight
      color: Local.Palette.foreground
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
    }
  }
}
