import QtQuick
import qs.Commons
import "." as Local

// One reading, said large, with the detail under it: CPU, memory, load. The
// figure is the point, so it is the biggest thing in the card and the label
// above it is small — the reverse of a settings row, where the name matters
// and the value is what it happens to be set to.
Rectangle {
  id: card
  property string label: ""
  property string value: ""
  property string note: ""
  default property alias content: middle.data

  implicitHeight: column.implicitHeight + Style.space(28)
  radius: Local.Palette.cardRadius
  color: Local.Palette.card
  border.width: Style.spacing.hairline
  border.color: Local.Palette.divider

  Column {
    id: column
    x: Style.space(14)
    y: Style.space(14)
    width: card.width - Style.space(28)
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      text: card.label
      color: Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.capitalization: Font.AllUppercase
      font.letterSpacing: Style.space(1)
    }

    Text {
      textFormat: Text.PlainText
      text: card.value
      color: Local.Palette.foreground
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.display
      font.bold: true
    }

    // Whatever the card wants between the figure and its note — the row of
    // per-core bars, a single bar, a second line of figures.
    Item {
      id: middle
      width: parent.width
      implicitHeight: childrenRect.height
      height: implicitHeight
      visible: children.length > 0
    }

    Text {
      textFormat: Text.PlainText
      visible: card.note !== ""
      width: parent.width
      text: card.note
      wrapMode: Text.WordWrap
      color: Local.Palette.muted
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
