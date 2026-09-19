import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  readonly property var rules: app.workspaceRules
  readonly property var setups: app.workspaceSetups
  readonly property var displays: (app.monitors !== undefined ? app.monitors : []).filter(function(m) {
    return m.connected !== false
  })

  readonly property var unsetWorkspaces: {
    var out = []
    for (var i = 1; i <= 10; i++) {
      var id = String(i)
      if (!setups.some(function(s) { return String(s.id) === id })) out.push(id)
    }
    return out
  }

  // Displays are named by what they say about themselves, so a rule follows
  // the screen rather than the socket it happens to be in.
  function displayOptions(noneLabel) {
    return [{ value: "", label: noneLabel }].concat(displays.map(function(m) {
      return { value: String(m.name), label: String(m.label || m.name) }
    }))
  }

  // ---------------------------------------------------------- applications
  //
  // The rules themselves live on Applications, one page per application. They
  // were here first, and here they were a second place writing the same Lua:
  // a reader who had set Slack from one page found the other saying it too,
  // with no way to tell which was the one that counted. What is left is the
  // way in, since an application bound to a workspace is a thing people come
  // to this page looking for.
  Ui.SettingGroup {
    title: "Applications"
    note: rules.length === 0
      ? "No application is bound to a workspace yet."
      : (rules.length === 1 ? "One application opens somewhere of its own."
                            : rules.length + " applications open somewhere of their own.")

    Ui.ActionRow {
      label: "Where applications open"
      description: "Which workspace an application opens on, how it shows, and whether it starts at login."
      buttonText: "Apps"
      onTriggered: app.pageId = "apps.list"
    }
  }

  // ------------------------------------------------------------ workspaces
  //
  // A rule for the place, not for what opens there — a different kind of
  // thing, so a line rather than only a heading marks where one ends.
  Rectangle {
    width: parent.width
    height: 1
    color: Ui.Palette.hairline
  }

  Ui.SettingGroup {
    title: "Workspace settings"
    note: unsetWorkspaces.length === 0 ? "Every workspace is set up." : ""

    Ui.PickerRow {
      label: "Set up a workspace"
      visible: unsetWorkspaces.length > 0
      description: "Its display, name, layout, and whether it stays when empty."
      value: ""
      options: [{ value: "", label: "Pick a workspace…" }].concat(unsetWorkspaces.map(function(id) {
        return { value: id, label: "Workspace " + id }
      }))
      onPicked: function(next) { if (next !== "") app.run(["workspaces", "setup", "add", next]) }
    }
  }
  //
  // The place rather than what opens there. Only a workspace with something
  // set gets a group, so ten empty groups do not bury the applications above.
  Repeater {
    model: setups

    delegate: Ui.SettingGroup {
      required property var modelData

      readonly property string id: String(modelData.id)
      readonly property bool ours: modelData.ours === true
      readonly property bool theirs: modelData.theirs === true

      width: parent.width
      title: "Workspace " + id

      Ui.TextRow {
        label: "Name"
        description: "Shown in the bar instead of the number."
        value: String(modelData.name || "")
        placeholder: id
        onCommitted: function(next) { app.run(["workspaces", "setup", "set", id, "name", next]) }
      }

      Ui.PickerRow {
        label: "Display"
        visible: displays.length > 1
        value: String(modelData.monitor || "")
        options: displayOptions("Any")
        onPicked: function(next) { app.run(["workspaces", "setup", "set", id, "monitor", next]) }
      }

      Ui.SwitchRow {
        label: "Default on its display"
        description: "The workspace a display shows when it is plugged in."
        visible: String(modelData.monitor || "") !== ""
        checked: modelData.default === true
        onRequested: function(next) { app.run(["workspaces", "setup", "set", id, "default", next ? "true" : "false"]) }
      }

      Ui.SwitchRow {
        label: "Keep when empty"
        description: "Stays in the bar with no windows on it."
        checked: modelData.persistent === true
        onRequested: function(next) { app.run(["workspaces", "setup", "set", id, "persistent", next ? "true" : "false"]) }
      }

      Ui.ChoiceRow {
        label: "Layout"
        options: [
          { value: "", label: "Default" },
          { value: "dwindle", label: "Dwindle" },
          { value: "master", label: "Master" },
          { value: "scrolling", label: "Scrolling" }
        ]
        value: String(modelData.layout || "")
        onPicked: function(next) { app.run(["workspaces", "setup", "set", id, "layout", next]) }
      }

      Ui.SwitchRow {
        label: "Borderless, no gaps"
        description: "Windows edge to edge with no borders, rounding or decorations."
        checked: modelData.minimal === true
        onRequested: function(next) { app.run(["workspaces", "setup", "set", id, "minimal", next ? "true" : "false"]) }
      }

      Ui.ActionRow {
        buttonText: "Remove"
        onTriggered: app.run(["workspaces", "setup", "remove", id])
      }
    }
  }

}
