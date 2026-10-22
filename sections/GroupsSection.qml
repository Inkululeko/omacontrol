import QtQuick
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// The tab strip drawn on grouped windows. Its colours come from the theme.
Ui.SectionBody {
  id: page
  property var app: null

  readonly property bool barOn: app.hyprValue("groupbar", true) === true

  Ui.SettingGroup {
    title: "Group bar"

    Ui.SwitchRow {
      label: "Group bar"
      description: "Shows the tab strip on grouped windows."
      checked: page.barOn
      onRequested: function(next) { page.app.setHypr("groupbar", next ? "true" : "false") }
      changed: page.app.isChanged("groupbar")
      onResetRequested: page.app.resetSetting("groupbar")
    }

    Ui.NumberRow {
      label: "Height"
      suffix: "px"
      enabled: page.barOn
      value: page.app.hyprValue("groupbar-height", 14)
      from: 0
      to: 40
      onCommitted: function(next) { page.app.setHypr("groupbar-height", next) }
      changed: page.app.isChanged("groupbar-height")
      onResetRequested: page.app.resetSetting("groupbar-height")
    }

    Ui.NumberRow {
      label: "Font size"
      suffix: "px"
      enabled: page.barOn
      value: page.app.hyprValue("groupbar-font-size", 8)
      from: 6
      to: 24
      onCommitted: function(next) { page.app.setHypr("groupbar-font-size", next) }
      changed: page.app.isChanged("groupbar-font-size")
      onResetRequested: page.app.resetSetting("groupbar-font-size")
    }

    Ui.SwitchRow {
      label: "Show titles"
      description: "Draws window titles in the tabs."
      enabled: page.barOn
      checked: page.app.hyprValue("groupbar-render-titles", true) === true
      onRequested: function(next) { page.app.setHypr("groupbar-render-titles", next ? "true" : "false") }
      changed: page.app.isChanged("groupbar-render-titles")
      onResetRequested: page.app.resetSetting("groupbar-render-titles")
    }

    Ui.NumberRow {
      label: "Indicator height"
      description: "Thickness of the active-tab indicator."
      suffix: "px"
      enabled: page.barOn
      value: page.app.hyprValue("groupbar-indicator-height", 3)
      from: 0
      to: 12
      onCommitted: function(next) { page.app.setHypr("groupbar-indicator-height", next) }
      changed: page.app.isChanged("groupbar-indicator-height")
      onResetRequested: page.app.resetSetting("groupbar-indicator-height")
    }

    Ui.NumberRow {
      label: "Rounding"
      description: "Corner radius of the tabs."
      suffix: "px"
      enabled: page.barOn
      value: page.app.hyprValue("groupbar-rounding", 1)
      from: 0
      to: 20
      onCommitted: function(next) { page.app.setHypr("groupbar-rounding", next) }
      changed: page.app.isChanged("groupbar-rounding")
      onResetRequested: page.app.resetSetting("groupbar-rounding")
    }

    Ui.SwitchRow {
      label: "Gradients"
      description: "Fades the tab backgrounds."
      enabled: page.barOn
      checked: page.app.hyprValue("groupbar-gradients", false) === true
      onRequested: function(next) { page.app.setHypr("groupbar-gradients", next ? "true" : "false") }
      changed: page.app.isChanged("groupbar-gradients")
      onResetRequested: page.app.resetSetting("groupbar-gradients")
    }

    Ui.SwitchRow {
      label: "Stacked"
      description: "Lays the tabs out vertically."
      enabled: page.barOn
      checked: page.app.hyprValue("groupbar-stacked", false) === true
      onRequested: function(next) { page.app.setHypr("groupbar-stacked", next ? "true" : "false") }
      changed: page.app.isChanged("groupbar-stacked")
      onResetRequested: page.app.resetSetting("groupbar-stacked")
    }

    Ui.SwitchRow {
      label: "Hide when alone"
      description: "Hides the strip when the group has one window."
      enabled: page.barOn
      checked: page.app.hyprValue("groupbar-disable-when-only", false) === true
      onRequested: function(next) { page.app.setHypr("groupbar-disable-when-only", next ? "true" : "false") }
      changed: page.app.isChanged("groupbar-disable-when-only")
      onResetRequested: page.app.resetSetting("groupbar-disable-when-only")
    }
  }
}
