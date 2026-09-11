import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  // A group each, because the two are the same three choices about different
  // artwork and nothing but the heading says which is which. The art goes
  // under the heading and above the buttons: it is what they are about, and
  // it is the only honest description of a file of ASCII. The row itself is
  // unnamed — the heading has already said what this is, and saying it again
  // beside the buttons only invites the reader to look for a difference.
  //
  // Both variants hand off to a flow of Omarchy's own — an editor for the
  // text, a file picker for the image — and this window holds the keyboard
  // exclusively while it is open, so whatever opened would sit behind it with
  // nothing reaching it. The window goes first.
  Ui.SettingGroup {
    title: "Screensaver"

    Ui.AsciiPreview {
      visible: text !== ""
      text: app.branding.screensaver !== undefined ? app.branding.screensaver : ""
    }

    Ui.BrandingRow {
      onChose: function(variant) {
        app.hide()
        app.run(["menu", "run", "style.screensaver." + variant])
      }
    }
  }

  Ui.SettingGroup {
    title: "About screen"

    Ui.AsciiPreview {
      visible: text !== ""
      text: app.branding.about !== undefined ? app.branding.about : ""
    }

    Ui.BrandingRow {
      onChose: function(variant) {
        app.hide()
        app.run(["menu", "run", "style.about." + variant])
      }
    }
  }
}
