import QtQuick
import qs.Commons
import "." as Local

// A pill that only reports — how many settings have been changed, that SMART
// passed. It looks like a Chip with the affordances taken away on purpose:
// same size and shape, filled rather than outlined, and nothing happens when
// you press it, because nothing is meant to.
Rectangle {
  id: tag
  property string text: ""
  // Accented when the fact is about something the reader did, plain when it is
  // something the machine is reporting.
  property bool accented: true
  // A glyph before the word, for a fact that is recognised faster by its
  // picture than read — a container is the whale before it is its name.
  property string icon: ""
  // The glyph's own colour where the thing it stands for has one. Otherwise
  // it is the word's.
  property var iconColor: null

  readonly property real iconSpace: icon !== "" ? glyph.implicitWidth + content.spacing : 0

  implicitWidth: label.implicitWidth + iconSpace + Style.space(18)
  implicitHeight: Style.space(20)
  radius: Local.Palette.pillRadius
  color: tag.accented ? Local.Palette.tint(0.16) : Local.Palette.shade(0.08)

  // Given less room than it asks for, it shortens the word rather than
  // spilling past its own edge: a container's name can be any length, and a
  // table cell is not.
  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(5)

    Text {
      id: glyph
      textFormat: Text.PlainText
      visible: tag.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: tag.icon
      color: tag.iconColor !== null && tag.iconColor !== undefined ? tag.iconColor : label.color
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      id: label
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(0, Math.min(implicitWidth, tag.width - Style.space(18) - tag.iconSpace))
      elide: Text.ElideRight
      text: tag.text
      color: tag.accented ? Local.Palette.accent : Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }
}
