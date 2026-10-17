import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A fact and its name, in a card of facts. The name is small, in capitals and
// in a column of its own, so the eye runs down the values the way it runs down
// a table; the value is the thing being read and gets the full body size. It
// may run to several lines — two GPUs are two lines rather than one line with
// a comma the reader has to find.
//
// `tag` is a pill after the value, for a qualifier that belongs to it rather
// than being a fact of its own: the channel beside a version.
NavRow {
  id: specRow
  property string value: ""
  property string tag: ""
  property real labelWidth: Style.space(104)

  readonly property real pad: Style.space(4)

  // On the value's first baseline, not its top: the two are set in different
  // sizes, and tops that line up leave the smaller word floating above.
  Text {
    textFormat: Text.PlainText
    y: specRow.pad + valueText.baselineOffset - baselineOffset
    width: specRow.labelWidth - Style.space(12)
    text: specRow.label.toUpperCase()
    elide: Text.ElideRight
    color: Local.Palette.muted
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
  }

  Item {
    x: specRow.labelWidth
    y: specRow.pad
    width: specRow.width - specRow.labelWidth
    // Asked for, not laid out: the row's own height is built from this.
    implicitHeight: Math.max(valueText.implicitHeight, tagPill.visible ? tagPill.implicitHeight : 0)
      + specRow.pad * 2

    Text {
      id: valueText
      textFormat: Text.PlainText
      width: Math.min(implicitWidth, parent.width
        - (tagPill.visible ? tagPill.implicitWidth + Style.space(10) : 0))
      text: specRow.value
      wrapMode: Text.WordWrap
      color: Local.Palette.foreground
      font.family: Local.Palette.fontFamily
      font.pixelSize: Style.font.body
    }

    // Centred on the value's first line, which is the line it qualifies.
    Local.Tag {
      id: tagPill
      visible: specRow.tag !== ""
      x: valueText.width + Style.space(10)
      y: (valueText.implicitHeight / Math.max(1, valueText.lineCount) - implicitHeight) / 2
      text: specRow.tag
    }
  }
}
