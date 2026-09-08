import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// One switch, as a tile: the icon and the switch on a line, the name and what
// it is doing underneath. Four across.
//
// Why a tile and not a row. These are the things flipped several times a day,
// and the question asked of them is *which of these are on right now* — asked
// of the whole set at once, from across the desk. A column of rows answers it
// with four small knobs in a vertical line, all in the same place, so the
// answer has to be read one row at a time. A tile that fills with the accent
// when it is on answers it in one glance and at any distance.
//
// So the fill is the state, and the switch is only the affordance. That is also
// why the whole tile is clickable: a target the size of a tile is one you can
// hit without looking, which is the point of putting these on the front page.
NavRow {
  id: tile

  property string glyph: ""
  property string note: ""
  property bool checked: false
  signal requested(bool next)

  // The grid sets the width, so the row's own full-width binding has to go.
  width: undefined
  // And the cursor is a ring around the tile rather than a band across it.
  showBand: false

  onNavActivate: tile.requested(!tile.checked)
  navKeys: [{ key: "Space", label: "Toggle" }]

  implicitHeight: body.implicitHeight + Style.space(28)

  Rectangle {
    id: surface
    anchors.fill: parent
    radius: Local.Palette.cardRadius
    color: tile.checked ? Local.Palette.accent
                        : (mouse.containsMouse ? Local.Palette.hover : Local.Palette.card)
    // An accent-filled tile needs no outline; an empty one is only a card.
    border.width: tile.checked ? 0 : Style.spacing.hairline
    border.color: Local.Palette.divider

    // The keyboard cursor, drawn just inside the edge so a tile under the
    // cursor reads the same whether it is filled or not.
    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.spacing.hairline
      radius: parent.radius
      color: "transparent"
      border.width: Style.normalBorderWidth
      border.color: tile.checked ? Local.Palette.onAccent : Local.Palette.accent
      visible: tile.current
    }
  }

  Column {
    id: body
    x: Style.space(14)
    y: Style.space(14)
    width: parent.width - Style.space(28)
    spacing: Style.space(10)

    Item {
      width: parent.width
      height: Math.max(badge.height, control.height)

      // Round, where the sidebar's icons are square: those name a place you
      // can go, this names a thing that is either on or off.
      Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(34)
        height: Style.space(34)
        radius: width / 2
        color: tile.checked ? Qt.rgba(1, 1, 1, 0.22) : Local.Palette.shade(0.12)

        Text {
          anchors.centerIn: parent
          text: tile.glyph
          color: tile.checked ? Local.Palette.onAccent : Local.Palette.foreground
          font.family: Local.Palette.fontFamily
          font.pixelSize: Style.font.icon
        }
      }

      ToggleSwitch {
        id: control
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        checked: tile.checked
        // The tile owns the click, so the switch does not take the cursor.
        interactive: false
        foreground: tile.checked ? Local.Palette.onAccent : Local.Palette.foreground
        // On a filled tile the accent track would vanish into the fill.
        accent: tile.checked ? Qt.rgba(1, 1, 1, 0.38) : Local.Palette.accent
      }
    }

    Column {
      width: parent.width
      spacing: Style.space(1)

      Text {
        width: parent.width
        text: tile.label
        elide: Text.ElideRight
        color: tile.checked ? Local.Palette.onAccent : Local.Palette.foreground
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        visible: tile.note !== ""
        width: parent.width
        text: tile.note
        elide: Text.ElideRight
        color: tile.checked ? Local.Palette.onAccent : Local.Palette.muted
        opacity: tile.checked ? 0.9 : 1
        font.family: Local.Palette.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: tile.requested(!tile.checked)
  }
}
