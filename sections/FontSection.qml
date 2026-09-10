import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  id: page
  property var app: null

  readonly property var fonts: app.state.fonts !== undefined ? app.state.fonts : []
  readonly property string chosen: app.fontPending !== "" ? app.fontPending
    : (app.state.font !== undefined ? String(app.state.font) : "")

  Ui.SettingGroup {
    Ui.NumberRow {
      label: "Text size"
      description: "Scales the shell, GTK apps, and terminals together."
      suffix: "px"
      value: app.state.textScale !== undefined ? Number(app.state.textScale) : 12
      from: 9
      to: 20
      onCommitted: function(next) { app.set("text-scale", next) }
      changed: app.isChanged("text-scale")
      onResetRequested: app.resetSetting("text-scale")
    }
  }

  // Every font set in itself. A list of fifty names tells you nothing about
  // the one thing a font is — a name in Helvetica and a name in Comic Sans
  // read identically when both are printed in the font you already have.
  //
  Ui.SettingGroup {
    title: "Font"
    visible: !searchEmpty

    Repeater {
      model: page.fonts

      delegate: Ui.SpecimenRow {
        required property var modelData
        width: parent.width
        family: String(modelData)
        current: String(modelData) === page.chosen
        onChose: app.setFont(String(modelData))
      }
    }
  }
}
