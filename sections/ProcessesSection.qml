import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// What the machine is busy with. It exists for one question — what is making
// this slow — so it leads with the three figures that answer it and then names
// the processes, sorted by whichever of them the reader is asking about.
Ui.SectionBody {
  property var app: null

  readonly property var cores: app.processes.cores !== undefined ? app.processes.cores : []
  readonly property var memory: app.processes.memory !== undefined ? app.processes.memory : ({})
  readonly property var load: app.processes.load !== undefined ? app.processes.load : ({})
  readonly property var items: app.processes.processes !== undefined ? app.processes.processes : []

  property int selectedProcess: -1

  readonly property string headerNote: {
    if (load.processes === undefined) return ""
    return load.processes + " processes · load " + load.one
  }

  // Faster than the other pages poll, because this is the one page whose whole
  // subject is what is true this second. Slower than a monitor would: the
  // reader is looking for what is heavy, not watching a graph.
  Timer {
    interval: 2000
    running: app.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: app.pollProcesses()
  }

  Ui.SettingGroup {
    RowLayout {
      width: parent.width
      spacing: Style.space(12)

      Ui.StatCard {
        Layout.fillWidth: true
        label: "CPU"
        value: app.processes.cpu !== undefined && app.processes.cpu !== null
          ? app.processes.cpu + " %" : "—"
        note: {
          var parts = []
          if (load.cores !== undefined) parts.push(load.cores + " cores")
          if (app.processes.temperature !== undefined && app.processes.temperature !== null)
            parts.push(app.processes.temperature + " °C")
          return parts.join(" · ")
        }

        // A bar per core rather than one average. The average hides the case
        // the reader is usually looking at: one core pinned by one thread,
        // which is a machine that feels slow while it reads as 6 % busy.
        Row {
          width: parent.width
          height: Style.space(24)
          spacing: Style.space(3)

          Repeater {
            model: cores

            Rectangle {
              required property var modelData
              width: (parent.width - (cores.length - 1) * Style.space(3)) / Math.max(1, cores.length)
              height: parent.height
              radius: Ui.Palette.chipRadius
              color: Ui.Palette.shade(0.12)

              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(Style.spacing.hairline,
                                 parent.height * Math.max(0, Math.min(100, Number(parent.modelData))) / 100)
                radius: parent.radius
                color: Ui.Palette.accent
              }
            }
          }
        }
      }

      Ui.StatCard {
        Layout.fillWidth: true
        label: "Memory"
        value: memory.used !== undefined ? app.formatBytes(memory.used) : "—"
        note: {
          if (memory.total === undefined) return ""
          var note = "of " + app.formatBytes(memory.total)
          if (Number(memory.swap) > 0) note += " · swap " + app.formatBytes(memory.swap)
          return note
        }

        Ui.Meter {
          width: parent.width
          value: memory.percent !== undefined ? Number(memory.percent) / 100 : 0
          warn: Number(memory.percent) >= 90
        }
      }

      Ui.StatCard {
        Layout.fillWidth: true
        label: "Load"
        value: load.one !== undefined ? String(load.one) : "—"
        // Five and fifteen minutes are what say whether the one-minute figure
        // is a spike or the way things have been.
        note: load.five !== undefined
          ? load.five + " over 5 min · " + load.fifteen + " over 15 min" : ""
      }
    }
  }

  Ui.SettingGroup {
    title: "Top processes"

    // The sort is the question the reader is asking, so it is a row of
    // choices rather than a dropdown: three options, all worth seeing at once,
    // and the answer changes which rows are even on the page.
    Row {
      spacing: Style.space(8)

      Repeater {
        model: [
          { id: "cpu", title: "CPU" },
          { id: "memory", title: "Memory" },
          { id: "name", title: "Name" }
        ]

        Ui.Chip {
          required property var modelData
          text: modelData.title
          on: app.processSort === modelData.id
          onClicked: {
            app.processSort = modelData.id
            // The sort happens where the rows are read, so the page asks
            // again rather than reordering the list it already has.
            app.pollProcesses()
            selectedProcess = -1
          }
        }
      }
    }

    Ui.DataTable {
      columns: [
        { title: "PID", weight: 0.8, align: "right" },
        { title: "Command", weight: 2.6 },
        { title: "CPU", weight: 1.2 },
        { title: "Memory", weight: 1.2 },
        { title: "Time", weight: 1.1, align: "right" }
      ]
      currentRow: selectedProcess
      emptyNote: "Nothing to report."
      rows: {
        var out = []
        // Both bars are scaled to the heaviest row rather than to an absolute
        // ceiling. A column of bars is read by comparing it down — which of
        // these is the heavy one — and against a ceiling of sixteen cores
        // every bar on an idle machine is a pixel, while the number beside it
        // says 10 %. The figures are absolute; the bars rank them.
        var busiest = 0
        var heaviest = 0
        for (var h = 0; h < items.length; h++) {
          busiest = Math.max(busiest, Number(items[h].cpu))
          heaviest = Math.max(heaviest, Number(items[h].memory))
        }
        for (var i = 0; i < items.length; i++) {
          var p = items[i]
          out.push({ cells: [
            { text: p.pid, align: "right" },
            { text: p.command, strong: true },
            { text: Number(p.cpu).toFixed(0) + " %",
              meter: busiest > 0 ? Number(p.cpu) / busiest : 0 },
            { text: app.formatBytes(p.memory),
              meter: heaviest > 0 ? Number(p.memory) / heaviest : 0 },
            { text: p.time, align: "right" }
          ] })
        }
        return out
      }
      onActivated: function(index) { selectedProcess = index }
    }

    Row {
      spacing: Style.space(8)

      readonly property var row: selectedProcess >= 0 && selectedProcess < items.length
        ? items[selectedProcess] : null

      // TERM and not KILL. A process asked to stop can save what it was
      // doing, and a settings window is not the place that decides it may not
      // — so the harder one is a second, separate press rather than the first.
      Ui.Chip {
        visible: parent.row !== null
        text: parent.row !== null ? "End " + parent.row.command : "End process"
        onClicked: {
          if (parent.row === null) return
          app.run(["processes", "end", parent.row.pid])
          app.pollProcesses()
        }
      }

      Ui.Chip {
        visible: parent.row !== null
        text: "Force quit"
        onClicked: {
          if (parent.row === null) return
          app.run(["processes", "kill", parent.row.pid])
          app.pollProcesses()
        }
      }

      // Everything past "what is heavy" belongs to a tool built for it, and
      // Omarchy already ships one.
      Ui.Chip {
        text: "Open in btop"
        onClicked: { app.run(["processes", "btop"]); app.hide() }
      }
    }
  }
}
