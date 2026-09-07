import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// What the disks are holding. Nothing on this page is a setting — a partition
// is not something you set — so it leads with the one figure everyone came
// for and offers the handful of things there are to *do* as actions.
Ui.SectionBody {
  property var app: null

  readonly property var summary: app.disk.summary !== undefined ? app.disk.summary : ({})
  readonly property var mounts: app.disk.mounts !== undefined ? app.disk.mounts : []
  readonly property var health: app.disk.health !== undefined ? app.disk.health : ({})
  readonly property var snapshots: app.disk.snapshots !== undefined ? app.disk.snapshots : []
  readonly property var breakdown: app.diskBreakdown !== null ? app.diskBreakdown : []

  property int selectedMount: -1

  // On the page root, not on the card that reads it: a QML binding resolves
  // names against its own object and the root of the file it is in, and
  // nothing in between. Declared on the Column, this was a ReferenceError that
  // only showed up as a note that never appeared.
  readonly property bool breakdownHasHome: {
    for (var i = 0; i < breakdown.length; i++)
      if (breakdown[i].label === "Home") return true
    return false
  }

  readonly property string headerNote: summary.size !== undefined
    ? app.formatBytes(summary.used) + " used of " + app.formatBytes(summary.size) : ""

  property Component headerControl: Component {
    Ui.Tag {
      visible: summary.device !== undefined && summary.device !== ""
      accented: false
      text: summary.model !== undefined && summary.model !== ""
        ? summary.device + " · " + summary.model : String(summary.device || "")
    }
  }

  // Mounting a stick is something that happens while you are looking at the
  // page, so the page keeps itself current — but the figures move slowly, and
  // five seconds is often enough for a `df`.
  Timer {
    interval: 5000
    running: app.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: app.pollDisk()
  }

  // Asked once, when the page opens. Walking directories is the only way to
  // answer it, and doing that on the poll would spin the disk for as long as
  // the reader looks at the page.
  Component.onCompleted: app.fetchDiskBreakdown()

  Ui.SettingGroup {
    Column {
      width: parent.width
      spacing: Style.space(12)

      Text {
        text: summary.size !== undefined
          ? app.formatBytes(summary.free) + " free"
          : "Reading the disk…"
        color: Ui.Palette.foreground
        font.family: Ui.Palette.fontFamily
        font.pixelSize: Style.font.display
        font.bold: true
      }

      // One bar divided into what is holding the space, rather than five bars
      // or a pie: the question is what share of one disk each thing has, and
      // shares of one thing read best as one length cut up.
      Row {
        width: parent.width
        height: Style.space(14)
        visible: breakdown.length > 0 && summary.size !== undefined

        Repeater {
          model: breakdown

          Rectangle {
            required property var modelData
            required property int index

            width: summary.size > 0
              ? parent.width * Math.max(0, Number(modelData.bytes)) / Number(summary.size) : 0
            height: parent.height
            // Spread along the distance between the accent and the
            // foreground, the same way the sidebar's cluster tints are, so
            // the slices are distinguishable and still in the theme.
            color: Ui.Palette.clusterTint(index, Math.max(2, breakdown.length))
          }
        }

        // Whatever the named slices do not account for is free.
        Rectangle {
          width: Math.max(0, parent.width - childrenAccounted)
          height: parent.height
          color: Ui.Palette.shade(0.12)

          readonly property real childrenAccounted: {
            var total = 0
            if (summary.size === undefined || Number(summary.size) <= 0) return 0
            for (var i = 0; i < breakdown.length; i++)
              total += parent.width * Math.max(0, Number(breakdown[i].bytes)) / Number(summary.size)
            return total
          }
        }
      }

      // The key under the bar, not on it: a slice thin enough to matter is
      // never wide enough to hold its own name.
      Flow {
        width: parent.width
        spacing: Style.space(14)
        visible: breakdown.length > 0

        Repeater {
          model: breakdown

          Row {
            required property var modelData
            required property int index
            spacing: Style.space(6)

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(9)
              height: Style.space(9)
              radius: width / 2
              color: Ui.Palette.clusterTint(index, Math.max(2, breakdown.length))
            }

            Text {
              text: modelData.label + " " + app.formatBytes(modelData.bytes)
              color: Ui.Palette.muted
              font.family: Ui.Palette.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }
      }

      // Said rather than left to be inferred from a slice that is not there.
      // A `du` that ran out of time is not a small number, it is no number,
      // and the space it could not account for is in System.
      Text {
        visible: app.diskBreakdown !== null && breakdown.length > 0
          && !breakdownHasHome
        width: parent.width
        text: "Your home directory was too large to measure in time, so its space is counted under System."
        wrapMode: Text.WordWrap
        color: Ui.Palette.muted
        font.family: Ui.Palette.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Ui.SettingGroup {
    title: "Mounts"

    Ui.DataTable {
      columns: [
        { title: "Mount", weight: 2.2 },
        { title: "Device", weight: 1.6 },
        { title: "Size", weight: 1, align: "right" },
        { title: "Used", weight: 1.3 },
        { title: "Type", weight: 1 }
      ]
      currentRow: selectedMount
      emptyNote: "Nothing mounted that this window can see."
      rows: {
        var out = []
        for (var i = 0; i < mounts.length; i++) {
          var m = mounts[i]
          var mounted = String(m.mount || "") !== ""
          var pct = m.percent !== null && m.percent !== undefined ? Number(m.percent) : null
          out.push({ cells: [
            // A partition with no mount point has its label to go by, and
            // failing that its device — it is still the row the reader is
            // looking for, so it is named rather than left blank.
            { text: mounted ? m.mount : (String(m.label || "") !== "" ? m.label : m.device),
              strong: true },
            { text: m.device, strong: mounted },
            { text: app.formatBytes(m.size), align: "right" },
            mounted && pct !== null
              ? { text: pct + " %", meter: pct / 100, warn: pct >= 90 }
              : { text: "not mounted" },
            { text: m.fstype }
          ] })
        }
        return out
      }
      onActivated: function(index) { selectedMount = index }
    }

    // The actions the table's selection governs, under it rather than one per
    // row: five rows each carrying four buttons is twenty buttons, nineteen
    // of which are about a row the reader is not looking at.
    Row {
      spacing: Style.space(8)

      Ui.Chip {
        readonly property var row: selectedMount >= 0 && selectedMount < mounts.length
          ? mounts[selectedMount] : null
        visible: row !== null
        text: row !== null && String(row.mount || "") !== "" ? "Unmount" : "Mount"
        onClicked: {
          if (row === null) return
          app.run(["disk", String(row.mount || "") !== "" ? "unmount" : "mount", row.path])
          app.pollDisk()
        }
      }

      Ui.Chip {
        readonly property var row: selectedMount >= 0 && selectedMount < mounts.length
          ? mounts[selectedMount] : null
        visible: row !== null && String(row.mount || "") !== ""
        text: "Open in files"
        onClicked: if (row !== null) app.run(["disk", "open", row.mount])
      }

      // Trimming tells the drive which blocks it may forget, which is a thing
      // to do to the machine rather than to whichever row is selected.
      Ui.Chip {
        text: "Run fstrim"
        onClicked: app.run(["disk", "trim"])
      }
    }
  }

  // Only when the drive answered. A health panel that is always empty — which
  // is what a machine where smartctl needs a password gives you — teaches the
  // reader to stop looking at it.
  Ui.SettingGroup {
    title: "Health"
    visible: !searchEmpty && health.passed !== undefined && health.passed !== null

    Ui.ReadingRow {
      label: "SMART"
      value: health.passed === true ? "Passed" : "Failing"
    }

    Ui.ReadingRow {
      visible: health.temperature !== undefined && health.temperature !== null
      label: "Temperature"
      value: health.temperature + " °C"
    }

    Ui.ReadingRow {
      visible: health.wear !== undefined && health.wear !== null
      label: "Wear"
      description: "How much of the drive's rated write life is used up."
      value: health.wear + " %"
    }

    Ui.ReadingRow {
      visible: health.hours !== undefined && health.hours !== null
      label: "Powered on"
      value: app.formatDuration(Number(health.hours) * 3600)
    }

    Ui.ReadingRow {
      visible: health.written !== undefined && health.written !== null
      label: "Written"
      value: app.formatBytes(health.written)
    }
  }

  Ui.SettingGroup {
    title: "Snapshots"
    visible: !searchEmpty && snapshots.length > 0
    note: "Taken by snapper, and by Omarchy before it updates packages."

    Ui.DataTable {
      columns: [
        { title: "No.", weight: 0.6 },
        { title: "Kind", weight: 1 },
        { title: "Description", weight: 2.6 },
        { title: "Taken", weight: 1.4, align: "right" }
      ]
      rows: {
        var out = []
        for (var i = 0; i < snapshots.length; i++)
          out.push({ cells: [
            { text: "#" + snapshots[i].number, strong: true },
            { text: snapshots[i].kind },
            { text: snapshots[i].description },
            { text: snapshots[i].date, align: "right" }
          ] })
        return out
      }
    }

    Ui.Chip {
      text: "Snapshot now"
      onClicked: { app.run(["disk", "snapshot"]); app.pollDisk() }
    }
  }
}
