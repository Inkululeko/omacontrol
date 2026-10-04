import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// A hairline between two rows of a card, running to the card's edges rather
// than stopping at its padding: rows of facts that read as one ruled list
// rather than as lines that happen to be near each other.
//
// It goes while a search is narrowing the page. The rows it sits between come
// and go with the search and the rules would not, so a card with two rows left
// in it would be left wearing every rule it had.
Rectangle {
  id: divider

  property var nav: null
  Component.onCompleted: {
    var node = divider.parent
    while (node) {
      if (node.searching !== undefined) { divider.nav = node; break }
      if (node.app !== undefined && node.app !== null && node.app.searching !== undefined) {
        divider.nav = node.app
        break
      }
      node = node.parent
    }
  }

  readonly property bool searchHidden: divider.nav !== null && divider.nav.searching === true
  visible: !searchHidden

  readonly property real inset: {
    var node = divider.parent
    while (node) {
      if (node.pad !== undefined) return node.pad
      node = node.parent
    }
    return 0
  }

  x: -inset
  width: (parent ? parent.width : 0) + inset * 2
  implicitHeight: Style.spacing.hairline
  height: implicitHeight
  color: Local.Palette.divider
}
