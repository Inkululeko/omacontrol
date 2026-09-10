import QtQuick
import QtQuick.Layouts
import qs.Commons
import "." as Local

// A block of readings about one thing, in columns.
//
// Not rows, and not a DataTable. A settings row is a name on the left and a
// value on the right, which is the right shape when the name is the question
// being asked — but fourteen facts about one connection asked that way is
// fourteen lines of mostly empty space, and the reader is scanning for one of
// them rather than reading down. The table is for comparing *between* things;
// this is for describing one.
//
// `layout` is the shape — `{ key:, label:, span:, small: }` per cell, or
// `{ rule: true }` for a full-width hairline — and `values` is what to print,
// keyed by `key`.
//
// Two properties rather than one list of label/value pairs, because the shape
// never changes and the values change every couple of seconds. Handing a
// Repeater a freshly built list each poll destroyed and recreated every cell,
// which collapsed the page's height for an instant — and a Flickable clamps
// its contentY to the shorter content and does not put it back, so anyone
// reading the foot of the page was thrown back up it every two seconds.
//
// `span` is in columns, for a value too long to sit in one — a pair of name
// servers. `small` sets the value a step down the type scale, for facts that
// sit below the ones the reader came for.
// An Item root, not a Column: a positioner computes its own implicitHeight and
// refuses an assignment to it ("implicitHeight is a read-only property"), which
// takes the whole file down and leaves the page blank.
Item {
  id: facts

  property var layout: []
  property var values: ({})
  property int columns: 4

  width: parent ? parent.width : 0

  readonly property real gap: Style.space(14)

  // Content rather than a row, so a group counts it as something and does not
  // take itself away as empty.
  implicitHeight: grid.implicitHeight

  // GridLayout rather than Grid: a plain Grid has no notion of a span, so a
  // value two columns wide simply took a single cell and shoved the rest of
  // its row off the edge — Channel and Receiving disappeared from the page
  // without a warning anywhere.
  GridLayout {
    id: grid
    width: parent.width
    columns: facts.columns
    columnSpacing: facts.gap
    rowSpacing: Style.space(11)

    Repeater {
      model: facts.layout

      delegate: Item {
        id: cell
        required property var modelData
        readonly property bool rule: cell.modelData.rule === true

        Layout.columnSpan: cell.rule ? facts.columns
          : (cell.modelData.span !== undefined ? Number(cell.modelData.span) : 1)
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        implicitHeight: cell.rule ? Style.space(9) : pair.implicitHeight

        Rectangle {
          visible: cell.rule
          width: parent.width
          height: Style.spacing.hairline
          anchors.verticalCenter: parent.verticalCenter
          color: Local.Palette.divider
        }

        Column {
          id: pair
          visible: !cell.rule
          width: parent.width
          spacing: Style.space(1)

          Text {
            width: parent.width
            text: cell.rule ? "" : String(cell.modelData.label).toUpperCase()
            elide: Text.ElideRight
            color: Local.Palette.muted
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 0.6
          }

          Text {
            width: parent.width
            // A value may carry its own line breaks — one name server per
            // line — so the cell grows rather than eliding the second away.
            wrapMode: Text.NoWrap
            text: {
              if (cell.rule) return ""
              var v = facts.values[cell.modelData.key]
              return v === undefined || v === null ? "—" : String(v)
            }
            elide: Text.ElideRight
            color: Local.Palette.foreground
            font.family: Local.Palette.fontFamily
            font.pixelSize: cell.modelData.small === true ? Style.font.bodySmall : Style.font.body
            font.bold: true
          }
        }
      }
    }
  }
}
