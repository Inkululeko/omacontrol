import QtQuick
import Quickshell
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
// glance. `strong` marks the cell that names the row, `icon` puts the thing's
// own picture in front of its name, and `mark` is a dot after it: a state that
// belongs to the thing rather than a value of its own, which is why it travels
// with the name instead of taking a column and a heading to explain itself.
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

  // Whether the keyboard can walk the rows.
  //
  // Off for the tables that are readings with an action underneath: there the
  // cursor belongs to the buttons, and sixty rows of process would be sixty
  // stops before the reader reached them. On for a table whose rows are the
  // way into something, where mouse-only would make the page unreachable from
  // the keyboard this window is otherwise driven by.
  property bool navigable: false
  // What ⏎ does to a row, for the legend.
  property string rowActionLabel: "Open"
  // Drawn at the right of the row the pointer is on, or of the row the cursor
  // is on: the affordance the mouse needs, where a mouse is already looking.
  // The first is a hint and never the only way in — the whole row takes the
  // click, and the keyboard reaches it with ⏎. Any further one is a second
  // action on that row, which nothing else offers: `{ id:, icon:, label: }`,
  // reported through `rowAction`.
  property var rowActions: []
  signal rowAction(int index, string id)
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

  // Anything painted over the card here is mixed down to an opaque colour
  // first. Both ends of the table are drawn in two pieces — rounded where
  // they carry the card's corner, square where they meet the rest of it — and
  // a translucent colour drawn twice is not the same colour: the overlap came
  // out a shade off, which read as a band with a lid on it. It is the header
  // as much as the last row; the header's seam was simply fainter.
  function overCard(colour) {
    return Qt.tint(Qt.tint(Local.Palette.background, Local.Palette.card), colour)
  }

  function rowFill(alpha) { return overCard(Local.Palette.tint(alpha)) }

  function columnWidth(index) {
    var available = table.width - table.pad * 2 - table.gap * (columns.length - 1)
    return Math.max(0, available * (columns[index].weight || 1) / table.totalWeight)
  }

  // Header and rows share one rounded outline, so the header reads as the top
  // of the table rather than as a band floating above it.
  //
  // `clip` is not what keeps them inside it. Clipping is to the bounding box
  // and knows nothing about a radius, so a filled header and a hovered last
  // row both painted square into the rounded corners — the card's outline ran
  // *behind* a block of colour at each end. The two ends round themselves
  // instead, and square off the edge that meets the rest of the table.
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
      radius: Local.Palette.cardRadius
      color: table.overCard(Local.Palette.shade(0.05))

      // Square again where the first row meets it.
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.radius
        color: parent.color
      }

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
          // The last row carries the bottom of the card, so its band is
          // rounded there and nowhere else.
          radius: index === table.rows.length - 1 ? Local.Palette.cardRadius : 0
          color: current ? table.rowFill(0.16)
                         : (rowMouse.containsMouse ? table.rowFill(0.08) : "transparent")

          // Square again where the row above meets it. Declared first so the
          // divider between rows still draws over it.
          Rectangle {
            visible: parent.radius > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.radius
            color: parent.color
          }

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

                // The figure first, then the bar in what is left of the
                // column. Stacked, the two sat a few pixels apart in a row
                // this short and the bar read as a strikethrough across its
                // own number.
                // An application's icon is how it is recognised — faster than
                // its name, and the reason a list of sixty-five can be scanned
                // at all. A missing one leaves the gap rather than a
                // placeholder, so the names stay in one column.
                Image {
                  id: cellIcon
                  visible: String(modelData.icon || "") !== ""
                  anchors.left: parent.left
                  anchors.leftMargin: modelData.indent === true ? Style.space(16) : 0
                  anchors.verticalCenter: parent.verticalCenter
                  width: visible ? Style.space(18) : 0
                  height: width
                  sourceSize.width: width * 2
                  sourceSize.height: width * 2
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                  source: {
                    var name = String(modelData.icon || "")
                    if (name === "") return ""
                    if (name.charAt(0) === "/") return "file://" + name
                    return Quickshell.iconPath(name, true)
                  }
                }

                Text {
                  id: cellText
                  anchors.left: cellIcon.visible ? cellIcon.right : parent.left
                  // A cell that belongs to the row above is stepped in from
                  // it, which says so without a word and without a column of
                  // its own. Indentation is the only thing in a table that
                  // can say "part of that" at a glance.
                  anchors.leftMargin: cellIcon.visible ? Style.space(8)
                    : (modelData.indent === true ? Style.space(16) : 0)
                  anchors.verticalCenter: parent.verticalCenter
                  // A figure with a bar beside it is sized to the figure;
                  // one on its own has the column.
                  width: meter.visible ? Math.min(implicitWidth + Style.space(4),
                                                  parent.width * 0.45)
                    : (String(modelData.mark || "") !== ""
                       ? Math.min(implicitWidth, parent.width - anchors.leftMargin
                                  - cellIcon.width - Style.space(14))
                       : parent.width - anchors.leftMargin - cellIcon.width)
                  text: modelData.text !== undefined ? String(modelData.text) : ""
                  elide: Text.ElideRight
                  horizontalAlignment: column.align === "right" ? Text.AlignRight : Text.AlignLeft
                  color: modelData.strong === true || current
                    ? Local.Palette.foreground : Local.Palette.muted
                  font.family: Local.Palette.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: modelData.strong === true
                }

                Text {
                  visible: String(modelData.mark || "") !== ""
                  anchors.left: cellText.right
                  anchors.leftMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  text: String(modelData.mark || "")
                  color: Local.Palette.accent
                  font.family: Local.Palette.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Meter {
                  id: meter
                  anchors.left: cellText.right
                  anchors.leftMargin: Style.space(7)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  visible: modelData.meter !== undefined && modelData.meter !== null
                  value: modelData.meter !== undefined && modelData.meter !== null
                    ? modelData.meter : 0
                  warn: modelData.warn === true
                }
              }
            }
          }

          // Hover on a table row is already the row's own highlight, so the
          // icon appears rather than fades: half-visible chrome on a row that
          // is not the one being pointed at reads as a disabled control.
          Row {
            visible: table.navigable && table.rowActions.length > 0
              && (rowMouse.containsMouse || current)
            // Above the row's own click area, which is declared after it and
            // would otherwise take every press: a sibling later in the file is
            // a sibling on top, and the icons would look live and do nothing.
            z: 1
            anchors.right: parent.right
            anchors.rightMargin: table.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Repeater {
              model: table.rowActions

              delegate: Item {
                required property var modelData

                width: Style.space(22)
                height: Style.space(22)

                Local.GlyphIcon {
                  anchors.fill: parent
                  glyph: String(modelData.icon || "")
                  size: Style.font.bodySmall
                  color: iconMouse.containsMouse ? Local.Palette.accent
                    : (current ? Local.Palette.foreground : Local.Palette.muted)
                }

                // Its own click, taken before the row's: the icon is the one
                // place on the row that does something other than open it.
                MouseArea {
                  id: iconMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    mouse.accepted = true
                    table.rowAction(index, String(modelData.id || ""))
                  }
                }
              }
            }
          }

          Local.NavCursor {
            anchors.fill: parent
            enabled: table.navigable
            visible: table.navigable
            navKeys: table.navigable ? [{ key: "\u23ce", label: table.rowActionLabel }] : []
            searchText: {
              var cells = modelData.cells || []
              return cells.length > 0 ? String(cells[0].text || "") : ""
            }
            // The window sets `current` on a registered row itself, so this
            // follows the cursor rather than declaring where it is: a binding
            // here would be overwritten the first time the keyboard moved,
            // and the row under the cursor would look like no row at all.
            onCurrentChanged: if (current) table.currentRow = index
            onNavActivate: {
              table.currentRow = index
              table.activated(index)
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
