import QtQuick
import qs.Commons
import "." as Local

// The design's one table, used for mounts, for processes and for snapshots.
//
// A table and not a list of rows because the reader is comparing down a
// column — which partition is fullest, what is eating the CPU — and that only
// works if the figures line up. Every column is a share of the width rather
// than a fixed size, so the same table holds a page of process names and a
// page of mount points without either being cut off.
//
// A row is `{ cells: [...] }`, and a cell is either `{ text: }` or
// `{ text:, meter: }` — a figure with the bar that makes it comparable at a
// glance. `strong` marks the cell that names the row.
Column {
  id: table

  // `{ title:, weight:, align: }`. Weight defaults to 1, align to left.
  property var columns: []
  property var rows: []
  // What the cursor is on, and what happens when it is acted on. A table with
  // no `activated` handler is a table you read rather than one you use.
  property int currentRow: -1
  signal activated(int index)
  // Named for the legend at the foot of the window: "End process", "Mount".
  property string actionLabel: ""
  property string emptyNote: "Nothing here."

  width: parent ? parent.width : 0
  spacing: 0

  readonly property real totalWeight: {
    var total = 0
    for (var i = 0; i < columns.length; i++) total += (columns[i].weight || 1)
    return Math.max(1, total)
  }

  readonly property real gap: Style.space(12)
  readonly property real pad: Style.space(14)

  function columnWidth(index) {
    var available = table.width - table.pad * 2 - table.gap * (columns.length - 1)
    return Math.max(0, available * (columns[index].weight || 1) / table.totalWeight)
  }

  // Header and rows share one rounded outline, so the header reads as the top
  // of the table rather than as a band floating above it.
  Rectangle {
    width: table.width
    implicitHeight: header.height + body.implicitHeight
    radius: Local.Palette.cardRadius
    color: Local.Palette.card
    border.width: Style.spacing.hairline
    border.color: Local.Palette.divider
    clip: true

    Rectangle {
      id: header
      width: parent.width
      height: Style.space(26)
      color: Local.Palette.shade(0.05)

      Row {
        anchors.left: parent.left
        anchors.leftMargin: table.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: table.gap

        Repeater {
          model: table.columns

          delegate: Text {
            required property var modelData
            required property int index

            width: table.columnWidth(index)
            text: modelData.title || ""
            elide: Text.ElideRight
            horizontalAlignment: modelData.align === "right" ? Text.AlignRight : Text.AlignLeft
            color: Local.Palette.muted
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Style.space(1)
          }
        }
      }
    }

    Column {
      id: body
      y: header.height
      width: parent.width
      spacing: 0

      Repeater {
        model: table.rows

        delegate: Rectangle {
          required property var modelData
          required property int index

          readonly property bool current: index === table.currentRow

          width: body.width
          implicitHeight: Style.space(30)
          height: implicitHeight
          color: current ? Local.Palette.tint(0.16)
                         : (rowMouse.containsMouse ? Local.Palette.tint(0.08) : "transparent")

          // Between rows, not around them: a border on every row would draw
          // a line above the first one, immediately under the header's own
          // edge, and the two together read as a double rule.
          Rectangle {
            visible: index > 0
            width: parent.width
            height: Style.spacing.hairline
            color: Local.Palette.divider
          }

          Row {
            anchors.left: parent.left
            anchors.leftMargin: table.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: table.gap

            Repeater {
              model: modelData.cells !== undefined ? modelData.cells : []

              delegate: Item {
                required property var modelData
                required property int index

                readonly property var column: table.columns[index] !== undefined
                  ? table.columns[index] : ({})

                width: table.columnWidth(index)
                implicitHeight: cellText.implicitHeight
                height: Math.max(implicitHeight, meter.visible ? meter.height : 0)

                // The bar sits under the figure rather than beside it: beside
                // it, the bar and the number each get half a column and both
                // end up too small to read.
                Meter {
                  id: meter
                  anchors.left: parent.left
                  anchors.bottom: parent.bottom
                  width: parent.width
                  visible: modelData.meter !== undefined && modelData.meter !== null
                  value: modelData.meter !== undefined && modelData.meter !== null
                    ? modelData.meter : 0
                  warn: modelData.warn === true
                }

                Text {
                  id: cellText
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  text: modelData.text !== undefined ? String(modelData.text) : ""
                  elide: Text.ElideRight
                  horizontalAlignment: column.align === "right" ? Text.AlignRight : Text.AlignLeft
                  color: modelData.strong === true || current
                    ? Local.Palette.foreground : Local.Palette.muted
                  font.family: Local.Palette.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: modelData.strong === true
                }
              }
            }
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              table.currentRow = index
              table.activated(index)
            }
          }
        }
      }

      // An empty table still has to say so, or the outline reads as a table
      // that has not loaded.
      Text {
        visible: table.rows.length === 0
        width: body.width - table.pad * 2
        x: table.pad
        topPadding: Style.space(10)
        bottomPadding: Style.space(10)
        text: table.emptyNote
        wrapMode: Text.WordWrap
        color: Local.Palette.muted
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
