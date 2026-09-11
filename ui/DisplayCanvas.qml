import QtQuick
import qs.Commons
import "." as Local
import "displays.js" as Geometry

// The displays as they are laid out, to be dragged into the arrangement they
// are actually in on the desk. A list of coordinates is the same information
// and nobody can read it: "is the laptop to the left of the monitor" is a
// question about a picture.
//
// Items are { name, label, x, y, width, height, scale, transform, focused },
// in Hyprland's own terms — mode and scale rather than logical size, since
// that is what the state holds.
Item {
  id: canvas

  property var items: []
  // Where a display was dropped, in logical pixels, after snapping.
  signal moved(string name, int x, int y)

  width: parent ? parent.width : 0
  implicitHeight: Style.space(220)

  readonly property var rects: {
    var out = []
    for (var i = 0; i < items.length; i++) {
      var size = Geometry.logicalSize(items[i])
      if (size.w <= 0 || size.h <= 0) continue
      out.push({ name: String(items[i].name), label: String(items[i].label),
                 focused: items[i].focused === true,
                 x: Number(items[i].x), y: Number(items[i].y), w: size.w, h: size.h })
    }
    return out
  }

  readonly property real pad: Style.space(14)
  readonly property var box: Geometry.bounds(rects)
  // The whole layout, scaled to fit whatever room the card gives it.
  readonly property real fit: Math.min((width - pad * 2) / Math.max(1, box.w),
                                       (implicitHeight - pad * 2) / Math.max(1, box.h))
  readonly property real originX: (width - box.w * fit) / 2
  readonly property real originY: (implicitHeight - box.h * fit) / 2

  Rectangle {
    anchors.fill: parent
    radius: Local.Palette.cardRadius
    color: Local.Palette.chrome
  }

  Repeater {
    model: canvas.rects

    Item {
      id: tile
      required property var modelData

      // While a tile is being dragged the pointer owns its position; the
      // rest of the time it follows the layout, which is what makes a
      // dropped display snap home the moment Hyprland says where it landed.
      // A plain binding would be broken for good by the first drag.
      Binding on x {
        when: !dragArea.drag.active
        value: canvas.originX + (tile.modelData.x - canvas.box.x) * canvas.fit
      }
      Binding on y {
        when: !dragArea.drag.active
        value: canvas.originY + (tile.modelData.y - canvas.box.y) * canvas.fit
      }
      width: modelData.w * canvas.fit
      height: modelData.h * canvas.fit

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(2)
        radius: Local.Palette.chipRadius
        color: dragArea.drag.active || dragArea.containsMouse
          ? Local.Palette.selected : Local.Palette.card
        border.width: Style.spacing.hairline
        border.color: tile.modelData.focused ? Local.Palette.accent : Local.Palette.divider

        Column {
          anchors.centerIn: parent
          spacing: Style.space(2)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(0, tile.width - Style.space(16))
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.modelData.label
            color: Local.Palette.foreground
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: tile.height > Style.space(46)
            text: tile.modelData.w + " × " + tile.modelData.h
            color: Local.Palette.muted
            font.family: Local.Palette.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.OpenHandCursor
        drag.target: tile
        drag.threshold: Style.space(3)

        onReleased: {
          // Back from the canvas to the layout: where the tile now is, in
          // logical pixels, snapped against the displays it was not dragging.
          var wanted = {
            name: tile.modelData.name,
            x: Math.round(canvas.box.x + (tile.x - canvas.originX) / canvas.fit),
            y: Math.round(canvas.box.y + (tile.y - canvas.originY) / canvas.fit),
            w: tile.modelData.w, h: tile.modelData.h
          }
          var others = []
          for (var i = 0; i < canvas.rects.length; i++)
            if (canvas.rects[i].name !== wanted.name) others.push(canvas.rects[i])

          // A threshold in logical pixels rather than in canvas pixels, or how
          // near is near enough would depend on the size of the window.
          var snapped = Geometry.snapPosition(wanted, others, Math.round(60 / canvas.fit))
          canvas.moved(wanted.name, snapped.x, snapped.y)
        }
      }
    }
  }
}
