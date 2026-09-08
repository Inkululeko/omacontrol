import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// One row the page's keyboard cursor can land on, and everything that follows
// from that: whether it is where the cursor is, what the keys do here, what
// the search thinks of it, and how it is handed back if this window set it.
//
// It knows nothing about what the row *looks* like. A setting is a name and a
// control (SettingRow); a line in a table is a grid of cells (TableRow); both
// are things the cursor walks onto and acts on, and that part is written once.
Item {
  id: navRow
  property string label: ""
  property string description: ""
  // Set by pages whose settings this window owns: whether the value on screen
  // was chosen here, and how to hand it back. A row that says nothing shows
  // nothing, so rows backed by live system state stay unmarked.
  property bool changed: false
  signal resetRequested()

  // ---------------- keyboard cursor ---------------------------------------
  // The window drives one cursor down the page; a row says what the cursor
  // means for its own control. A row that answers neither signal is still
  // navigable, it just has nothing to do when activated.
  property bool current: false
  // While a row owns the keyboard outright — a dropdown is open, a field is
  // being typed into — the window stops handling keys and lets it through.
  property bool navBlocking: false
  signal navActivate()
  signal navStep(int delta)

  // What the keys do on this row, for the legend at the foot of the window.
  // A row that says nothing contributes nothing, which is the honest answer
  // for a row with no control of its own.
  property var navKeys: []

  // Told, not asked: a window that has to work out for itself which row is
  // holding the keyboard gets it wrong the moment the row list is rebuilt
  // underneath it.
  onNavBlockingChanged: {
    var nav = navController()
    if (nav && nav.setNavBlocked !== undefined) nav.setNavBlocked(navRow, navBlocking)
  }

  // Set once the row is up, so bindings below can follow what the window is
  // doing without every page having to pass it down.
  property var nav: null

  // A row the search does not match leaves the page rather than dimming: the
  // page then reads as the settings that matched, and nothing else.
  // The heading a row sits under counts as part of it: searching "blur" finds
  // the settings under Blur whether or not the word is in their own names,
  // which is also how the index counts them.
  property string groupTitle: ""
  readonly property bool searchHidden: nav !== null && nav.searching === true
    && !nav.rowMatches(navRow.label, navRow.description, navRow.groupTitle)
  visible: !searchHidden

  // Rows are nested several layers inside a page, so the controller is found
  // by walking up rather than passed down through every group.
  // The walk stops at the page rather than the window — a window is not the
  // visual parent of what it shows — so what is looked for is the page's own
  // handle on the window, which every section is given when it is loaded.
  function navController() {
    var node = navRow.parent
    while (node) {
      if (node.registerNavRow !== undefined) return node
      if (node.app !== undefined && node.app !== null
          && node.app.registerNavRow !== undefined) return node.app
      node = node.parent
    }
    return null
  }

  // For a row that takes the keyboard and then gives it back.
  function navRelease() {
    var nav = navController()
    if (nav && nav.navTakeFocus !== undefined) nav.navTakeFocus()
  }

  Component.onCompleted: {
    var node = navRow.parent
    while (node) {
      if (node.searchEmpty !== undefined) { navRow.groupTitle = String(node.title || ""); break }
      node = node.parent
    }
    navRow.nav = navController()
    if (navRow.nav) navRow.nav.registerNavRow(navRow)
  }

  Component.onDestruction: {
    var nav = navController()
    if (nav) nav.unregisterNavRow(navRow)
  }
  // The card the row sits in, when it sits in one. The cursor band runs to
  // the card's inside edges rather than to the row's, so a walked cursor
  // reads as a band across the card instead of a box drawn around the text —
  // and it has to stop exactly at the edge, since overshooting a card is
  // visible in a way that overshooting a bare page never was.
  property real bandInset: {
    var node = navRow.parent
    while (node) {
      if (node.pad !== undefined) return node.pad
      node = node.parent
    }
    return Style.space(10)
  }

  // A row that is not row-shaped draws its own cursor. A band with negative
  // insets is right for a setting spanning a card and wrong for a tile in a
  // grid, where it would bleed over the neighbours.
  property bool showBand: true

  Rectangle {
    id: cursorBand
    visible: navRow.current && navRow.showBand
    anchors.fill: parent
    anchors.leftMargin: -navRow.bandInset
    anchors.rightMargin: -navRow.bandInset
    anchors.topMargin: -Style.space(6)
    anchors.bottomMargin: -Style.space(6)
    radius: Local.Palette.chipRadius
    color: Local.Palette.tint(0.14)
  }

  // A subclass declares its own shape as ordinary children — there is no
  // content slot, because a slot's holder would itself be a child and an
  // Item's default property is where children go, so the holder would be
  // handed to itself.
  //
  // Which makes the row as tall as the tallest thing in it, measured from
  // what each child *asks* for rather than from where it ended up: the row's
  // height is built from this, so reading laid-out geometry closes the circle
  // and Qt freezes the row at whatever height it happened to have.
  width: parent ? parent.width : 0
  opacity: enabled ? 1 : 0.45
  implicitHeight: {
    var tallest = 0
    for (var i = 0; i < children.length; i++) {
      // The cursor band fills the row rather than contributing to it.
      if (children[i] === cursorBand) continue
      tallest = Math.max(tallest, children[i].implicitHeight)
    }
    return tallest
  }
}
