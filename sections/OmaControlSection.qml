import QtQuick
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// OmaControl's own settings, apart from the desktop's. They still live where
// Omarchy keeps a bar widget's settings — the gear's entry in shell.json — so
// `omarchy bar set` reaches them too.
Ui.SectionBody {
  id: page
  property var app: null

  readonly property string widgetId: "io.github.twiking.omacontrol"

  // A widget's settings are keys of its layout entry, so with the gear out of
  // the bar there is nowhere for them to go.
  readonly property bool inBar: {
    var layout = app.barState.layout !== undefined ? app.barState.layout : ({})
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      var list = layout[sections[s]] || []
      for (var i = 0; i < list.length; i++)
        if (String(list[i]) === widgetId) return true
    }
    return false
  }

  Ui.SettingGroup {
    title: "Bar button"

    Ui.SwitchRow {
      label: "Show active-switch count"
      description: page.inBar
        ? "Counts Night light, Do not disturb and Stay awake on the gear. Network and battery warnings show either way."
        : "Add OmaControl to the bar to use this."
      enabled: page.inBar
      checked: page.app.barState.activeSwitchCount !== false
      onRequested: function(next) { page.app.set("bar-active-switch-count", next ? "true" : "false") }
      changed: page.app.isChanged("bar-active-switch-count")
      onResetRequested: page.app.resetSetting("bar-active-switch-count")
    }
  }
}
