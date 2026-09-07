import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// The page the window opens on, and the only one that is not about a subject.
// It answers three questions in the order they are asked: is anything wrong,
// what do I flip several times a day, and what did I come here to start.
//
// Nothing here is a setting of its own. Every switch is Omarchy's, every
// notice points at the page that can actually fix it, and both are shown
// rather than kept — so this page cannot disagree with the bar.
Ui.SectionBody {
  property var app: null

  readonly property var toggles: app.overview.toggles !== undefined ? app.overview.toggles : []

  // Two sources, deliberately. What only the shell can answer — how full
  // /boot is — comes from the reader; what the window already holds is
  // derived here rather than read a second time.
  readonly property var attention: {
    var items = []
    var reported = app.overview.attention !== undefined ? app.overview.attention : []
    for (var i = 0; i < reported.length; i++) items.push(reported[i])

    // A monitor on a fractional scale hands Xwayland windows an integer scale
    // and lets them be resampled, which is why one application looks soft
    // when the rest do not. Said once, however many monitors are on one.
    var fractional = []
    for (var m = 0; m < app.monitors.length; m++) {
      var scale = Number(app.monitors[m].scale)
      if (isFinite(scale) && Math.round(scale * 100) % 100 !== 0)
        fractional.push({ name: String(app.monitors[m].name || ""), scale: scale })
    }
    if (fractional.length > 0) {
      var names = []
      var scales = []
      for (var f = 0; f < fractional.length; f++) {
        names.push(fractional[f].name)
        scales.push(fractional[f].scale)
      }
      items.push({
        title: names.join(", ") + (fractional.length === 1 ? " runs" : " run")
          + " at a fractional scale",
        note: scales.join(", ") + " · Xwayland windows can come out soft.",
        actionLabel: "Open Displays",
        page: "displays"
      })
    }

    if (app.selfBehind > 0)
      items.push({
        title: "OmaControl is " + app.selfBehind
          + (app.selfBehind === 1 ? " commit behind" : " commits behind"),
        note: "Checked once this opening.",
        actionLabel: "Update",
        update: true
      })

    return items
  }

  readonly property string headerNote: {
    var up = app.processes.load !== undefined && app.processes.load.uptime !== undefined
      ? "up " + app.formatDuration(app.processes.load.uptime) : ""
    if (attention.length === 0) return up
    var needs = attention.length === 1 ? "1 thing needs attention"
      : attention.length + " things need attention"
    return up === "" ? needs : up + " · " + needs
  }

  // Switch state is held in the running system — hyprsunset's temperature, the
  // shell's own do-not-disturb — so it can be changed from the bar or a
  // keybinding while this page is on screen. Polling is how the page agrees
  // with them rather than arguing.
  Timer {
    interval: 5000
    running: app.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: app.pollOverview()
  }

  // Only for the uptime in the header. A page that showed CPU and memory here
  // too would be the Processes page with fewer rows, and the reader would have
  // two places to look at the same figure.
  Timer {
    interval: 30000
    running: app.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: app.pollProcesses()
  }

  // First, because the reader did not ask for it: anything they would want to
  // know before they got to whatever they opened the window for.
  Ui.SettingGroup {
    title: "Needs attention"
    visible: !searchEmpty && attention.length > 0

    Repeater {
      model: attention

      Ui.ActionRow {
        required property var modelData

        label: modelData.title
        description: modelData.note !== undefined ? modelData.note : ""
        buttonText: modelData.actionLabel !== undefined ? modelData.actionLabel : "Open"
        onTriggered: {
          if (modelData.update === true) {
            if (app.selfId !== "") app.run(["plugin", "update", app.selfId])
          } else if (modelData.page !== undefined) {
            app.pageId = modelData.page
          } else if (modelData.action === "disk") {
            app.pageId = "disk"
          }
        }
      }
    }
  }

  // A note when there is nothing, rather than a group that quietly is not
  // there: "nothing needs attention" is the answer the reader came for, and a
  // page that omits it leaves them wondering whether it looked.
  Ui.SettingGroup {
    visible: !searchEmpty && attention.length === 0 && app.loaded

    Ui.ReadingRow {
      label: "Nothing needs attention"
      description: "Nothing full, nothing behind, nothing misconfigured that this window can see."
    }
  }

  Ui.SettingGroup {
    title: "Toggles"

    Repeater {
      model: toggles

      Ui.SwitchRow {
        required property var modelData

        label: modelData.label
        description: modelData.note !== undefined ? modelData.note : ""
        checked: modelData.on === true
        // The command that owns the switch is the one that flips it, side
        // effects and all — starting hyprsunset, telling the bar to redraw.
        // Then the page asks again rather than assuming it worked.
        onRequested: {
          app.run(["overview", "toggle", modelData.id])
          app.pollOverview()
        }
      }
    }
  }

  // The two things people open a window to start rather than to change. They
  // are not settings, so they are not dressed as settings: a row and a button
  // that runs it, and the window gets out of the way.
  Ui.SettingGroup {
    title: "Do now"

    Ui.ActionRow {
      label: "Set a reminder"
      description: "Asks how long, then notifies you."
      buttonText: "Set"
      onTriggered: { app.run(["overview", "reminder"]); app.hide() }
    }

    Ui.ActionRow {
      label: "Record the screen"
      description: "Pick a region or a display; stop it from the bar."
      buttonText: "Record"
      onTriggered: { app.run(["overview", "record"]); app.hide() }
    }

    Ui.ActionRow {
      label: "Take a screenshot"
      buttonText: "Capture"
      onTriggered: { app.run(["overview", "screenshot"]); app.hide() }
    }
  }
}
