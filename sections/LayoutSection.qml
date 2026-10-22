import QtQuick
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// The tiling engine, and the knobs belonging to whichever one is running.
// Showing all three engines' settings at once would mostly show settings that
// do nothing, so each group appears only when its engine is the active one.
Ui.SectionBody {
  id: page
  property var app: null

  readonly property string engine: String(app.hyprValue("layout", "dwindle"))

  Ui.SettingGroup {
    title: "Engine"

    Ui.ChoiceRow {
      label: "Layout"
      description: "Scrolling gives you niri-style side-scrolling columns."
      value: page.engine
      options: [
        { value: "dwindle", label: "Dwindle" },
        { value: "master", label: "Master" },
        { value: "scrolling", label: "Scrolling" }
      ]
      onPicked: function(next) { page.app.setHypr("layout", next) }
      changed: page.app.isChanged("layout")
      onResetRequested: page.app.resetSetting("layout")
    }
  }

  Ui.SettingGroup {
    title: "Dwindle"
    visible: !searchEmpty && page.engine === "dwindle"

    Ui.SwitchRow {
      label: "Preserve split"
      description: "Keeps the split direction when a window closes."
      checked: page.app.hyprValue("dwindle-preserve-split", true) === true
      onRequested: function(next) { page.app.setHypr("dwindle-preserve-split", next ? "true" : "false") }
      changed: page.app.isChanged("dwindle-preserve-split")
      onResetRequested: page.app.resetSetting("dwindle-preserve-split")
    }

    Ui.SwitchRow {
      label: "Smart split"
      description: "Picks the split direction from where in the window you drop."
      checked: page.app.hyprValue("dwindle-smart-split", false) === true
      onRequested: function(next) { page.app.setHypr("dwindle-smart-split", next ? "true" : "false") }
      changed: page.app.isChanged("dwindle-smart-split")
      onResetRequested: page.app.resetSetting("dwindle-smart-split")
    }

    Ui.ChoiceRow {
      label: "Split side"
      description: "Where a new window lands."
      value: String(page.app.hyprValue("dwindle-force-split", 0))
      options: [
        { value: "0", label: "Cursor" },
        { value: "1", label: "Before" },
        { value: "2", label: "After" }
      ]
      onPicked: function(next) { page.app.setHypr("dwindle-force-split", next) }
      changed: page.app.isChanged("dwindle-force-split")
      onResetRequested: page.app.resetSetting("dwindle-force-split")
    }

    Ui.FactorRow {
      label: "Split bias"
      description: "Above 1.0 favours splitting side by side."
      minimum: 0.5
      maximum: 2
      value: page.app.hyprValue("dwindle-split-width-multiplier", 1)
      onCommitted: function(next) { page.app.setHypr("dwindle-split-width-multiplier", next) }
      changed: page.app.isChanged("dwindle-split-width-multiplier")
      onResetRequested: page.app.resetSetting("dwindle-split-width-multiplier")
    }

    Ui.FactorRow {
      label: "Split ratio"
      description: "Size of a new split relative to its sibling."
      minimum: 0.5
      maximum: 1.5
      value: page.app.hyprValue("dwindle-default-split-ratio", 1)
      onCommitted: function(next) { page.app.setHypr("dwindle-default-split-ratio", next) }
      changed: page.app.isChanged("dwindle-default-split-ratio")
      onResetRequested: page.app.resetSetting("dwindle-default-split-ratio")
    }
  }

  Ui.SettingGroup {
    title: "Master"
    visible: !searchEmpty && page.engine === "master"

    Ui.PercentRow {
      label: "Master size"
      description: "Fraction of the screen the master window takes."
      value: page.app.hyprValue("master-mfact", 0.55)
      onCommitted: function(next) { page.app.setHypr("master-mfact", next) }
      changed: page.app.isChanged("master-mfact")
      onResetRequested: page.app.resetSetting("master-mfact")
    }

    Ui.ChoiceRow {
      label: "Master side"
      description: "Which edge the master window occupies."
      value: String(page.app.hyprValue("master-orientation", "left"))
      options: [
        { value: "left", label: "Left" },
        { value: "right", label: "Right" },
        { value: "top", label: "Top" },
        { value: "bottom", label: "Bottom" },
        { value: "center", label: "Center" }
      ]
      onPicked: function(next) { page.app.setHypr("master-orientation", next) }
      changed: page.app.isChanged("master-orientation")
      onResetRequested: page.app.resetSetting("master-orientation")
    }

    Ui.ChoiceRow {
      label: "New windows"
      description: "Where a newly opened window goes."
      value: String(page.app.hyprValue("master-new-status", "master"))
      options: [
        { value: "master", label: "Master" },
        { value: "slave", label: "Slave" },
        { value: "inherit", label: "Inherit" }
      ]
      onPicked: function(next) { page.app.setHypr("master-new-status", next) }
      changed: page.app.isChanged("master-new-status")
      onResetRequested: page.app.resetSetting("master-new-status")
    }
  }

  Ui.SettingGroup {
    title: "Scrolling"
    visible: !searchEmpty && page.engine === "scrolling"

    Ui.PercentRow {
      label: "Column width"
      description: "Fraction of the screen one column takes. 97% shows one at a time."
      value: page.app.hyprValue("scrolling-column-width", 0.5)
      onCommitted: function(next) { page.app.setHypr("scrolling-column-width", next) }
      changed: page.app.isChanged("scrolling-column-width")
      onResetRequested: page.app.resetSetting("scrolling-column-width")
    }

    Ui.SwitchRow {
      label: "Fill on one column"
      description: "Lets a lone column use the whole screen."
      checked: page.app.hyprValue("scrolling-fullscreen-on-one-column", false) === true
      onRequested: function(next) { page.app.setHypr("scrolling-fullscreen-on-one-column", next ? "true" : "false") }
      changed: page.app.isChanged("scrolling-fullscreen-on-one-column")
      onResetRequested: page.app.resetSetting("scrolling-fullscreen-on-one-column")
    }
  }
}
