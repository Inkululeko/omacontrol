import QtQuick
import qs.Commons
import "." as Local

// Four rungs of signal, drawn rather than set in a glyph: icon fonts vary in
// what they carry, and a missing glyph would leave every network looking
// equally strong.
//
// One component rather than a copy in each place that shows signal — the list
// rows and the connection card — so a network cannot read as three rungs in
// one place and four in the other.
Item {
  id: signal

  // NetworkManager's percentage, which is what every caller already has.
  property int strength: 0
  property bool accented: false
  // The card draws these larger than a list row does; the proportions are the
  // same either way.
  property real unit: 1

  // Five steps, because the bar's network widget has five and the same signal
  // must not read as a different strength in two places on one screen. Its
  // Model.js buckets NetworkManager's percentage in flat twenty-point steps
  // (`ceil(strength / 20)`, clamped), one step per glyph, so a rung here is
  // one of its glyphs:
  //
  //   1–20 %  one     21–40 %  two    41–60 %  three
  //   61–80 % four    81–100 % five
  //
  // Four rungs was ours, invented, and it disagreed with the bar over most of
  // the scale — 72 % drew full here and three-of-five there.
  readonly property int rungs: Math.max(1, Math.min(5, Math.ceil(strength / 20)))
  readonly property int steps: 5

  implicitWidth: bars.implicitWidth
  implicitHeight: (Style.spaceReal(4) + (signal.steps - 1) * Style.spaceReal(2.5)) * unit

  Row {
    id: bars
    anchors.bottom: parent.bottom
    spacing: Style.space(2) * signal.unit

    Repeater {
      model: signal.steps
      delegate: Rectangle {
        required property int index
        width: Style.space(3) * signal.unit
        // spaceReal, not space: a fifth rung on the old three-point step made
        // the icon taller than the row it sits in, and space() rounds a
        // fractional step away.
        height: (Style.spaceReal(4) + index * Style.spaceReal(2.5)) * signal.unit
        anchors.bottom: parent.bottom
        radius: 1
        color: signal.accented ? Local.Palette.accent : Local.Palette.foreground
        opacity: index < signal.rungs ? 1 : 0.25
      }
    }
  }
}
