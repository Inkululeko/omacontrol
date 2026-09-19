import QtQuick
import qs.Commons
import "." as Local

// Everything this desktop can be told about one application: where it opens,
// how it shows, whether it starts at login. It is a component rather than a
// page because two pages ask for it — the application's own page, and the
// workspace picker that sends you there — and a setting written in two places
// is a setting that disagrees with itself in one of them.
//
// Every row writes through `workspaces set <class>`, which creates the rule
// on the first write: there is nothing to add first.
SettingGroup {
  property var app: null
  property var displays: []

  function workspaceOptions() {
    var out = [{ value: "", label: "Wherever it was last open" }]
    for (var i = 1; i <= 10; i++) out.push({ value: String(i), label: "Workspace " + i })
    out.push({ value: "special", label: "Scratchpad" })
    return out
  }

  // Displays are named by what they say about themselves, so a rule follows
  // the screen rather than the socket it happens to be in.
  function displayOptions(noneLabel) {
    return [{ value: "", label: noneLabel }].concat(displays.map(function(m) {
      return { value: String(m.name), label: String(m.label || m.name) }
    }))
  }

  property var modelData: ({})

  readonly property string cls: String(modelData.class)
  readonly property string name: String(modelData.name || modelData.class)
  readonly property bool ours: modelData.ours === true
  readonly property bool theirs: modelData.theirs === true
  readonly property bool onWorkspace: String(modelData.workspace || "") !== ""
  readonly property bool floating: modelData.shown === "floating"

  width: parent ? parent.width : 0
  title: name

  Local.PickerRow {
    label: "Opens on"
    value: String(modelData.workspace || "")
    options: workspaceOptions()
    onPicked: function(next) { app.run(["workspaces", "set", cls, "workspace", next]) }
  }

  Local.SwitchRow {
    label: "Open in the background"
    description: "Send the window to its workspace without switching to it."
    visible: onWorkspace
    checked: modelData.silent === true
    onRequested: function(next) { app.run(["workspaces", "set", cls, "silent", next ? "true" : "false"]) }
  }

  Local.PickerRow {
    label: "Open on display"
    visible: displays.length > 1
    value: String(modelData.monitor || "")
    options: displayOptions("Whichever has the focus")
    onPicked: function(next) { app.run(["workspaces", "set", cls, "monitor", next]) }
  }

  // One choice, not two switches: a fullscreen window is neither tiled nor
  // floating in any way you can see, so offering both was offering a
  // combination with no meaning.
  Local.ChoiceRow {
    label: "Shown as"
    description: "Floating opens a free window rather than one tiled into the layout."
    options: [
      { value: "tiled", label: "Tiled" },
      { value: "floating", label: "Floating" },
      { value: "fullscreen", label: "Fullscreen" }
    ]
    value: String(modelData.shown || "tiled")
    onPicked: function(next) { app.run(["workspaces", "set", cls, "shown", next]) }
  }

  // What only a floating window can do sits under Floating, and goes away
  // with it — Hyprland ignores a pin on a tiled window rather than saying so.
  // A share of the screen rather than pixels, so one rule fits every
  // display. Empty hands the size back to the application.
  Local.TextRow {
    label: "Width"
    description: "Percent of the screen. Leave empty to let the application decide."
    visible: floating
    value: Number(modelData.width) > 0 ? String(modelData.width) : ""
    placeholder: "e.g. 60"
    onCommitted: function(next) { app.run(["workspaces", "set", cls, "width", next.trim()]) }
  }

  Local.TextRow {
    label: "Height"
    description: "Percent of the screen."
    visible: floating
    value: Number(modelData.height) > 0 ? String(modelData.height) : ""
    placeholder: "e.g. 60"
    onCommitted: function(next) { app.run(["workspaces", "set", cls, "height", next.trim()]) }
  }

  Local.SwitchRow {
    label: "Centred"
    description: "Opens in the middle of the screen."
    visible: floating
    checked: modelData.center === true
    onRequested: function(next) { app.run(["workspaces", "set", cls, "center", next ? "true" : "false"]) }
  }

  Local.SwitchRow {
    label: "Pinned"
    description: "Stays on screen whichever workspace you switch to."
    visible: floating
    checked: modelData.pin === true
    onRequested: function(next) { app.run(["workspaces", "set", cls, "pin", next ? "true" : "false"]) }
  }

  // Only for an application with a desktop entry: that is what says how
  // to launch it. A bare window class has no command to start.
  Local.SwitchRow {
    label: "Start when you log in"
    visible: String(modelData.desktop || "") !== ""
    checked: modelData.autostart === true
    onRequested: function(next) { app.run(["workspaces", "set", cls, "autostart", next ? String(modelData.desktop) : ""]) }
  }

  Local.SwitchRow {
    label: "Don't take focus when opening"
    description: "The window appears without pulling you away from what you were doing."
    checked: modelData.noInitialFocus === true
    onRequested: function(next) { app.run(["workspaces", "set", cls, "no_initial_focus", next ? "true" : "false"]) }
  }

  Local.SwitchRow {
    label: "Keep the screen awake"
    description: "No dimming or locking while a window of this application is open."
    checked: modelData.idleInhibit === true
    onRequested: function(next) { app.run(["workspaces", "set", cls, "idle_inhibit", next ? "true" : "false"]) }
  }

  Local.SwitchRow {
    label: "Hide from screen sharing"
    description: "Shows as a black rectangle to anyone you share your screen with."
    checked: modelData.noScreenShare === true
    onRequested: function(next) { app.run(["workspaces", "set", cls, "no_screen_share", next ? "true" : "false"]) }
  }
}
