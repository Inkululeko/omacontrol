import QtQuick
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  id: page
  property var app: null
  Ui.SettingGroup {
    title: "Gaps and borders"

    Ui.NumberRow {
      label: "Inner gaps"
      suffix: "px"
      value: page.app.hyprValue("gaps-in", 0)
      from: 0
      to: 40
      onCommitted: function(next) { page.app.setHypr("gaps-in", next) }
      changed: page.app.isChanged("gaps-in")
      onResetRequested: page.app.resetSetting("gaps-in")
    }

    Ui.NumberRow {
      label: "Outer gaps"
      suffix: "px"
      value: page.app.hyprValue("gaps-out", 0)
      from: 0
      to: 60
      onCommitted: function(next) { page.app.setHypr("gaps-out", next) }
      changed: page.app.isChanged("gaps-out")
      onResetRequested: page.app.resetSetting("gaps-out")
    }

    Ui.NumberRow {
      label: "Border width"
      suffix: "px"
      value: page.app.hyprValue("border-size", 0)
      from: 0
      to: 10
      onCommitted: function(next) { page.app.setHypr("border-size", next) }
      changed: page.app.isChanged("border-size")
      onResetRequested: page.app.resetSetting("border-size")
    }

    Ui.NumberRow {
      label: "Floating gaps"
      description: "Gap around floating windows. 0 follows the inner gap."
      suffix: "px"
      value: page.app.hyprValue("float-gaps", 0)
      from: 0
      to: 40
      onCommitted: function(next) { page.app.setHypr("float-gaps", next) }
      changed: page.app.isChanged("float-gaps")
      onResetRequested: page.app.resetSetting("float-gaps")
    }

    Ui.NumberRow {
      label: "Workspace gaps"
      description: "Extra space between workspaces while they slide past."
      suffix: "px"
      value: page.app.hyprValue("gaps-workspaces", 0)
      from: 0
      to: 100
      onCommitted: function(next) { page.app.setHypr("gaps-workspaces", next) }
      changed: page.app.isChanged("gaps-workspaces")
      onResetRequested: page.app.resetSetting("gaps-workspaces")
    }

    Ui.SwitchRow {
      label: "Border inside window"
      description: "Counts the border as part of the window rather than drawing it outside."
      checked: page.app.hyprValue("border-part-of-window", true) === true
      onRequested: function(next) { page.app.setHypr("border-part-of-window", next ? "true" : "false") }
      changed: page.app.isChanged("border-part-of-window")
      onResetRequested: page.app.resetSetting("border-part-of-window")
    }

    Ui.NumberRow {
      label: "Corner rounding"
      suffix: "px"
      value: page.app.hyprValue("rounding", 0)
      from: 0
      to: 30
      onCommitted: function(next) { page.app.setHypr("rounding", next) }
      changed: page.app.isChanged("rounding")
      onResetRequested: page.app.resetSetting("rounding")
    }

    Ui.FactorRow {
      label: "Roundness curve"
      description: "2.0 is a circle; higher gets you a squircle."
      minimum: 1
      maximum: 10
      value: page.app.hyprValue("rounding-power", 2)
      onCommitted: function(next) { page.app.setHypr("rounding-power", next) }
      changed: page.app.isChanged("rounding-power")
      onResetRequested: page.app.resetSetting("rounding-power")
    }
  }

  Ui.SettingGroup {
    title: "Snapping"

    // "Enabled": the heading has already said which setting this is.
    Ui.SwitchRow {
      label: "Enabled"
      description: "Snap floating windows to each other and to screen edges."
      checked: page.app.hyprValue("snap", false) === true
      onRequested: function(next) { page.app.setHypr("snap", next ? "true" : "false") }
      changed: page.app.isChanged("snap")
      onResetRequested: page.app.resetSetting("snap")
    }

    Ui.NumberRow {
      label: "Snap distance"
      description: "How close a floating window gets before it snaps to another."
      suffix: "px"
      enabled: page.app.hyprValue("snap", false) === true
      value: page.app.hyprValue("snap-window-gap", 10)
      from: 0
      to: 50
      onCommitted: function(next) { page.app.setHypr("snap-window-gap", next) }
      changed: page.app.isChanged("snap-window-gap")
      onResetRequested: page.app.resetSetting("snap-window-gap")
    }

    Ui.NumberRow {
      label: "Snap to edges"
      description: "How close a floating window gets before it snaps to a screen edge."
      suffix: "px"
      enabled: page.app.hyprValue("snap", false) === true
      value: page.app.hyprValue("snap-monitor-gap", 10)
      from: 0
      to: 50
      onCommitted: function(next) { page.app.setHypr("snap-monitor-gap", next) }
      changed: page.app.isChanged("snap-monitor-gap")
      onResetRequested: page.app.resetSetting("snap-monitor-gap")
    }
  }

  Ui.SettingGroup {
    title: "Focus and depth"

    Ui.SwitchRow {
      label: "Full opacity"
      description: "Omarchy fades every window to 98.5%, which multiplies with the settings below. This clears it, so 100% is 100%."
      checked: page.app.hyprValue("opaque-windows", false) === true
      onRequested: function(next) { page.app.setHypr("opaque-windows", next ? "true" : "false") }
      changed: page.app.isChanged("opaque-windows")
      onResetRequested: page.app.resetSetting("opaque-windows")
    }

    Ui.PercentRow {
      label: "Active window opacity"
      value: page.app.hyprValue("active-opacity", 1)
      onCommitted: function(next) { page.app.setHypr("active-opacity", next) }
      changed: page.app.isChanged("active-opacity")
      onResetRequested: page.app.resetSetting("active-opacity")
    }

    Ui.PercentRow {
      label: "Inactive window opacity"
      value: page.app.hyprValue("inactive-opacity", 1)
      onCommitted: function(next) { page.app.setHypr("inactive-opacity", next) }
      changed: page.app.isChanged("inactive-opacity")
      onResetRequested: page.app.resetSetting("inactive-opacity")
    }

    Ui.PercentRow {
      label: "Fullscreen opacity"
      description: "Opacity while a window is fullscreen."
      value: page.app.hyprValue("fullscreen-opacity", 1)
      onCommitted: function(next) { page.app.setHypr("fullscreen-opacity", next) }
      changed: page.app.isChanged("fullscreen-opacity")
      onResetRequested: page.app.resetSetting("fullscreen-opacity")
    }

    Ui.SwitchRow {
      label: "Dim inactive windows"
      checked: page.app.hyprValue("dim-inactive", false) === true
      onRequested: function(next) { page.app.setHypr("dim-inactive", next ? "true" : "false") }
      changed: page.app.isChanged("dim-inactive")
      onResetRequested: page.app.resetSetting("dim-inactive")
    }

    Ui.PercentRow {
      label: "Dim strength"
      enabled: page.app.hyprValue("dim-inactive", false) === true
      value: page.app.hyprValue("dim-strength", 0.5)
      onCommitted: function(next) { page.app.setHypr("dim-strength", next) }
      changed: page.app.isChanged("dim-strength")
      onResetRequested: page.app.resetSetting("dim-strength")
    }

    Ui.PercentRow {
      label: "Special workspace dim"
      description: "Dimming applied behind a special workspace."
      value: page.app.hyprValue("dim-special", 0.2)
      onCommitted: function(next) { page.app.setHypr("dim-special", next) }
      changed: page.app.isChanged("dim-special")
      onResetRequested: page.app.resetSetting("dim-special")
    }

    Ui.PercentRow {
      label: "Dim around"
      description: "Dimming behind windows using the dimaround window rule."
      value: page.app.hyprValue("dim-around", 0.4)
      onCommitted: function(next) { page.app.setHypr("dim-around", next) }
      changed: page.app.isChanged("dim-around")
      onResetRequested: page.app.resetSetting("dim-around")
    }

    Ui.SwitchRow {
      label: "Dim behind modals"
      description: "Darkens a window while one of its dialogs is open."
      checked: page.app.hyprValue("dim-modal", true) === true
      onRequested: function(next) { page.app.setHypr("dim-modal", next ? "true" : "false") }
      changed: page.app.isChanged("dim-modal")
      onResetRequested: page.app.resetSetting("dim-modal")
    }
  }

  Ui.SettingGroup {
    title: "Animations"

    Ui.SwitchRow {
      label: "Enabled"
      checked: page.app.hyprValue("animations", true) === true
      onRequested: function(next) { page.app.setHypr("animations", next ? "true" : "false") }
      changed: page.app.isChanged("animations")
      onResetRequested: page.app.resetSetting("animations")
    }

    Ui.FactorRow {
      label: "Speed"
      description: "A multiplier over the animation set Omarchy ships. Higher is faster."
      enabled: page.app.hyprValue("animations", true) === true
      minimum: 0.25
      maximum: 3
      value: page.app.hyprValue("animation-speed", 1)
      onCommitted: function(next) { page.app.setHypr("animation-speed", next) }
      changed: page.app.isChanged("animation-speed")
      onResetRequested: page.app.resetSetting("animation-speed")
    }

    Ui.SwitchRow {
      label: "Wrap workspaces"
      description: "Slides the short way when moving between the first and last workspace."
      enabled: page.app.hyprValue("animations", true) === true
      checked: page.app.hyprValue("animations-wraparound", false) === true
      onRequested: function(next) { page.app.setHypr("animations-wraparound", next ? "true" : "false") }
      changed: page.app.isChanged("animations-wraparound")
      onResetRequested: page.app.resetSetting("animations-wraparound")
    }
  }

  Ui.SettingGroup {
    title: "Beyond these settings"

    Ui.ActionRow {
      label: "Window rules and animations"
      description: "Open looknfeel.lua for anything this page does not cover."
      buttonText: "Edit…"
      onTriggered: page.app.run(["menu", "run", "style.hyprland"])
    }
  }
}
