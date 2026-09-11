import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  // A display you own is not always plugged in, and Hyprland matches its
  // monitor rules again every time it is: a display can be set up here before
  // the cable is in, and keeps what it was given.
  readonly property var displays: app.monitors !== undefined ? app.monitors : []

  readonly property var arrangeable: {
    var out = []
    for (var i = 0; i < displays.length; i++) {
      var d = displays[i]
      // A display that is off, mirroring another or not here at all has no
      // place in the layout — Hyprland gives it none either.
      if (d.connected === false || d.off === true || String(d.mirror || "") !== "") continue
      if (Number(d.width) <= 0 || Number(d.height) <= 0) continue
      var position = String(d.position || "").split("x")
      out.push({ name: String(d.name), label: String(d.label || d.name),
                 focused: d.focused === true,
                 x: Number(position[0] || 0), y: Number(position[1] || 0),
                 width: Number(d.width), height: Number(d.height),
                 scale: Number(d.scale) || 1, transform: Number(d.transform) || 0 })
    }
    return out
  }

  // Brightness is not in the state document, so the page asks for it — while
  // it is the page on screen and the window is open, like every other reading
  // this window shows.
  Timer {
    interval: 5000
    running: app.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: app.pollBrightness()
  }

  // Where the displays are relative to one another, as a picture. The same
  // fact as a pair of coordinates per display and the only form anybody can
  // read it in: "is the laptop left of the monitor" is a question about a
  // shape. Only with two to arrange — one display is not an arrangement.
  Ui.SettingGroup {
    title: "Arrangement"
    note: "Drag a display. Edges snap to their neighbours, so the pointer can always cross."
    visible: !searchEmpty && arrangeable.length > 1

    Ui.DisplayCanvas {
      items: arrangeable
      onMoved: function(name, x, y) {
        app.set("monitor:" + name + ":position", x + "x" + y)
      }
    }
  }

  // Every display gets its own group, titled with its name, so what a control
  // writes is never in doubt. A display carries its resolution and its scale;
  // both mean nothing without saying which screen they are about.
  Repeater {
    model: displays

    delegate: Ui.SettingGroup {
      id: displayGroup
      required property var modelData

      // The identity a setting is written against: the display's own
      // description where it has one, so what is set here stays with the screen
      // rather than with the socket it happened to be in. `label` is what to
      // call it, since the identity itself reads as machinery.
      readonly property string name: String(modelData.name)
      readonly property string label: String(modelData.label || modelData.name)
      readonly property bool connected: modelData.connected !== false
      readonly property bool off: modelData.off === true
      readonly property var settings: modelData.settings || ({})
      readonly property var configured: modelData.configured || ({})
      readonly property var modes: modelData.modes || []
      readonly property string output: String(modelData.output || "")

      // The two halves of a mode. Hyprland takes them as one string, and
      // nobody picks a resolution and a refresh rate as one decision.
      readonly property string mode: String(modelData.mode)
      readonly property string resolution: mode.indexOf("@") > 0 ? mode.split("@")[0] : mode
      readonly property string refresh: mode.indexOf("@") > 0 ? mode.split("@")[1] : ""

      readonly property var resolutions: {
        var seen = {}
        var out = []
        for (var i = 0; i < modes.length; i++) {
          var size = String(modes[i]).split("@")[0]
          if (seen[size]) continue
          seen[size] = true
          out.push({ value: size, label: size.split("x").join(" × ") })
        }
        return out
      }

      readonly property var refreshRates: {
        var out = []
        for (var i = 0; i < modes.length; i++) {
          var parts = String(modes[i]).split("@")
          if (parts[0] !== resolution || parts.length < 2) continue
          out.push({ value: parts[1], label: Math.round(Number(parts[1])) + " Hz" })
        }
        return out
      }

      // What the page can offer to mirror: every other display that is here.
      // Mirroring names an output rather than a display, which is Hyprland's
      // own rule and the one place a connector is the right answer.
      readonly property var mirrorOptions: {
        var out = [{ value: "", label: "Off" }]
        for (var i = 0; i < displays.length; i++) {
          var other = displays[i]
          if (other.name === name || other.connected === false) continue
          if (String(other.output || "") === "") continue
          out.push({ value: String(other.output), label: String(other.label || other.name) })
        }
        return out
      }

      readonly property int brightness: {
        var all = app.displayBrightness
        return output !== "" && all[output] !== undefined ? Number(all[output]) : -1
      }

      width: parent.width
      title: label + (connected ? "" : "  (not connected)")
      note: !connected
        ? "Kept for the next time this display is plugged in."
        : Object.keys(configured).length > 0 && Object.keys(settings).length === 0
          ? "Set in your own Hyprland config."
          : ""

      // The title says which screen this is. The connector is the part you
      // cannot tell from that, and the part that changes between docks — so it
      // is shown, and nothing is written against it.
      Ui.ReadingRow {
        label: "Connector"
        visible: !searchHidden && connected && output !== ""
        value: output
      }

      // Everything below this switch is about a screen that is showing
      // something, so it leads.
      Ui.SwitchRow {
        label: "Enabled"
        visible: !searchHidden && connected
        checked: !off
        onRequested: function(next) {
          app.set("monitor:" + name + ":disabled", next ? "false" : "true")
        }
        changed: app.isChanged("monitor:" + name + ":disabled")
        onResetRequested: app.resetSetting("monitor:" + name + ":disabled")
      }

      Ui.PickerRow {
        label: "Resolution"
        // A display that is not here reports no modes, so what it was given is
        // the only option there is to show.
        description: connected ? "" : "Applied when the display comes back."
        visible: !searchHidden && !off
        value: resolution
        options: {
          var listed = resolutions
          if (resolution !== "preferred"
              && !listed.some(function(item) { return item.value === resolution }))
            listed = [{ value: resolution, label: resolution.split("x").join(" × ") }].concat(listed)
          return [{ value: "preferred", label: "Preferred (what the display asks for)" }].concat(listed)
        }
        // A resolution is picked as a resolution, so the fastest rate the
        // display can do at it comes with it rather than being a second
        // decision the reader did not know they had made.
        onPicked: function(next) {
          if (next === "preferred") { app.set("monitor:" + name + ":mode", "preferred"); return }
          var fastest = ""
          for (var i = 0; i < modes.length; i++) {
            var parts = String(modes[i]).split("@")
            if (parts[0] !== next || parts.length < 2) continue
            if (fastest === "" || Number(parts[1]) > Number(fastest)) fastest = parts[1]
          }
          app.set("monitor:" + name + ":mode", fastest === "" ? next : next + "@" + fastest)
        }
        changed: app.isChanged("monitor:" + name + ":mode")
        onResetRequested: app.resetSetting("monitor:" + name + ":mode")
      }

      Ui.PickerRow {
        label: "Refresh rate"
        visible: !searchHidden && !off && refreshRates.length > 1
        value: refresh
        options: refreshRates
        onPicked: function(next) { app.set("monitor:" + name + ":mode", resolution + "@" + next) }
      }

      Ui.FactorRow {
        label: "Scale"
        visible: !searchHidden && !off
        minimum: 0.5
        maximum: 3
        value: Number(modelData.scale)
        onCommitted: function(next) { app.set("monitor:" + name + ":scale", next) }
        changed: app.isChanged("monitor:" + name + ":scale")
        onResetRequested: app.resetSetting("monitor:" + name + ":scale")
      }

      Ui.ChoiceRow {
        label: "Rotation"
        visible: !searchHidden && !off
        value: String(Number(modelData.transform) || 0)
        options: [
          { value: "0", label: "None" },
          { value: "1", label: "90°" },
          { value: "2", label: "180°" },
          { value: "3", label: "270°" }
        ]
        onPicked: function(next) { app.set("monitor:" + name + ":transform", next) }
        changed: app.isChanged("monitor:" + name + ":transform")
        onResetRequested: app.resetSetting("monitor:" + name + ":transform")
      }

      Ui.ChoiceRow {
        label: "Variable refresh"
        // The range is the display's own answer to whether this is worth
        // turning on, and it is not anywhere else on the desktop.
        description: String(modelData.vrrRange || "") !== ""
          ? "This display varies between " + modelData.vrrRange + " Hz."
          : "Lets the display follow what is being drawn instead of its own clock."
        visible: !searchHidden && !off && connected
        value: String(Number(modelData.vrr) || 0)
        options: [
          { value: "0", label: "Off" },
          { value: "1", label: "On" },
          { value: "2", label: "Fullscreen only" }
        ]
        onPicked: function(next) { app.set("monitor:" + name + ":vrr", next) }
        changed: app.isChanged("monitor:" + name + ":vrr")
        onResetRequested: app.resetSetting("monitor:" + name + ":vrr")
      }

      // Only for a display that says it can: a switch that cannot do anything
      // is worse than no switch, because it gives no reason why.
      Ui.SwitchRow {
        label: "HDR"
        description: "Wide colour and ten-bit output. Everything that is not HDR is mapped into it, which some desktops render washed out."
        visible: !searchHidden && !off && modelData.hdrCapable === true
        checked: modelData.hdr === true
        onRequested: function(next) {
          app.set("monitor:" + name + ":hdr", next ? "true" : "false")
        }
        changed: app.isChanged("monitor:" + name + ":hdr")
        onResetRequested: app.resetSetting("monitor:" + name + ":hdr")
      }

      Ui.PickerRow {
        label: "Mirror"
        description: "Show what another display is showing."
        visible: !searchHidden && !off && connected && mirrorOptions.length > 1
        value: String(modelData.mirror || "")
        options: mirrorOptions
        onPicked: function(next) { app.set("monitor:" + name + ":mirror", next) }
        changed: app.isChanged("monitor:" + name + ":mirror")
        onResetRequested: app.resetSetting("monitor:" + name + ":mirror")
      }

      // The backlight on a laptop panel, DDC over the cable on a desktop
      // monitor — and nothing at all where neither answers, which is most
      // docks. No change mark: this is the screen in front of you rather than
      // a setting this window keeps.
      Ui.PercentRow {
        label: "Brightness"
        visible: !searchHidden && !off && brightness >= 0
        value: brightness / 100
        onCommitted: function(next) {
          app.run(["display", "brightness", name, String(Math.round(next * 100))])
        }
      }

      // Only once there is something to forget: for a display sitting in front
      // of you with nothing set, there is nothing this would undo.
      Ui.ActionRow {
        visible: !searchHidden && (Object.keys(settings).length > 0 || !connected)
        buttonText: "Forget Display"
        onTriggered: app.set("monitor-forget", name)
      }
    }
  }

  // Setting up a display that is not plugged in: nothing can list it, so it is
  // typed. Its model is the thing to type — that is what still names this
  // screen at the next desk, where the connector only says which socket was
  // free. A connector name is taken too, and becomes the model's identity the
  // first time the display is actually seen.
  Ui.SettingGroup {
    title: "Another display"
    visible: !searchEmpty

    Ui.TextRow {
      label: "Set up a display that is not connected"
      // No real model as the example: a placeholder naming an actual monitor
      // reads as a value this window detected rather than as an illustration.
      description: "Its model, as hyprctl monitors all prints it under description, or a connector name like DP-3. What you set is kept for when it arrives."
      placeholder: "Model, or a connector like DP-3"
      value: ""
      buttonText: "Add Display"
      clearOnCommit: true
      onCommitted: function(next) { app.set("monitor-remember", next) }
    }
  }
}
