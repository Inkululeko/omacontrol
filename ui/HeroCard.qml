import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// The one thing a page is about, named once at the top of it: its picture in
// the theme's accent, its name at display size, and the few facts that tell it
// apart in a line underneath. Whatever acts on the whole thing goes at the
// right, as children.
//
// It is not a setting and has no row to match, so it steps aside while a
// search is narrowing the page, the way a heading over nothing would.
Rectangle {
  id: hero
  property string glyph: ""
  property string title: ""
  property string subtitle: ""
  default property alias trailing: trailingHolder.data

  property var nav: null
  Component.onCompleted: {
    var node = hero.parent
    while (node) {
      if (node.searching !== undefined) { hero.nav = node; break }
      if (node.app !== undefined && node.app !== null && node.app.searching !== undefined) {
        hero.nav = node.app
        break
      }
      node = node.parent
    }
  }
  visible: !(hero.nav !== null && hero.nav.searching === true)

  readonly property real pad: Style.space(20)

  width: parent ? parent.width : 0
  implicitHeight: Math.max(badge.height, texts.implicitHeight, trailingHolder.implicitHeight) + pad * 2
  radius: Local.Palette.cardRadius
  color: Local.Palette.card
  border.width: Style.spacing.hairline
  border.color: Local.Palette.divider

  // Placed rather than anchored, like every box here whose height is measured
  // from what is inside it.
  Rectangle {
    id: badge
    x: hero.pad
    y: (hero.height - height) / 2
    width: Style.space(52)
    height: width
    radius: width / 2
    color: Local.Palette.accent

    Text {
      anchors.centerIn: parent
      text: hero.glyph
      color: Local.Palette.onAccent
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.display
    }
  }

  Column {
    id: texts
    x: badge.x + badge.width + Style.space(16)
    y: (hero.height - implicitHeight) / 2
    width: hero.width - x - hero.pad
      - (trailingHolder.implicitWidth > 0 ? trailingHolder.implicitWidth + Style.space(16) : 0)
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: hero.title
      elide: Text.ElideRight
      color: Local.Palette.foreground
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.display
      font.bold: true
    }

    Text {
      visible: hero.subtitle !== ""
      width: parent.width
      text: hero.subtitle
      elide: Text.ElideRight
      color: Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  Item {
    id: trailingHolder
    x: hero.width - hero.pad - width
    y: (hero.height - height) / 2
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
    width: implicitWidth
    height: implicitHeight
  }
}
