import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  Ui.SettingGroup {
    Ui.BrandingRow {
      label: "Screensaver"
      onChose: function(variant) { app.run(["menu", "run", "style.screensaver." + variant]) }
    }

    Ui.BrandingRow {
      label: "About screen"
      onChose: function(variant) { app.run(["menu", "run", "style.about." + variant]) }
    }
  }
}
