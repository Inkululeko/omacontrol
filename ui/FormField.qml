import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

// One labelled field of a form, with its own validation.
//
// A form is not a page of settings: the label goes over the box, the box is
// the width of the form, and what is wrong with a value is said under the box
// it is wrong in rather than collected into one line by the button. The rule
// is the caller's — `error` is whatever it wants to say — and this decides
// only *when* to say it: after the field has been left, never while it is
// first being typed into. Telling someone their name is too short while they
// are still on the second letter is the form arguing with them.
Column {
  id: field

  property string label: ""
  property string placeholder: ""
  property alias text: input.text
  // Empty means the value is good.
  property string error: ""
  property bool touched: false
  readonly property bool showsError: error !== "" && touched

  signal accepted()

  // The box, not the column: focus given to the column lands nowhere.
  function focusInput() { input.forceActiveFocus() }

  width: parent ? parent.width : 0
  spacing: Style.space(6)

  Text {
    textFormat: Text.PlainText
    text: field.label
    color: field.showsError ? Local.Palette.bad : Local.Palette.foreground
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Item {
    width: parent.width
    height: input.implicitHeight

    TextField {
      id: input
      anchors.fill: parent
      placeholderText: field.placeholder
      foreground: Local.Palette.foreground
      accent: Local.Palette.accent
      onAccepted: field.accepted()
      // Left, so the answer is complete. A rule applied on every keystroke
      // marks a field wrong on the way to being right.
      onActiveFocusChanged: if (!activeFocus && text !== "") field.touched = true
    }

    // Drawn over the control rather than through it: the kit builds its own
    // border from the focus state, and a red one has to survive that.
    Rectangle {
      anchors.fill: parent
      visible: field.showsError
      color: "transparent"
      radius: Style.cornerRadius
      border.width: Style.normalBorderWidth
      border.color: Local.Palette.bad
    }
  }

  Text {
    textFormat: Text.PlainText
    visible: field.showsError
    width: parent.width
    text: field.error
    wrapMode: Text.WordWrap
    color: Local.Palette.bad
    font.family: Local.Palette.fontFamily
    font.pixelSize: Style.font.caption
  }
}
