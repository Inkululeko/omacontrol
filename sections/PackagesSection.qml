import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// What pacman has and what it is waiting to do. The counts are local and free;
// the list of what is *available* is a database sync, so it is cached and the
// page says how old it is. Nothing here updates anything on its own — every
// action opens a terminal, because installing a kernel wants a password, a
// confirmation and somewhere for the output to go.
Ui.SectionBody {
  property var app: null

  readonly property var pending: app.packages.pending !== undefined ? app.packages.pending : []
  readonly property int checkedAt: app.packages.checkedAt !== undefined ? Number(app.packages.checkedAt) : 0

  // Which of the three the reader is asking for. The filter is on the page
  // rather than in the reader: the whole list is already in hand, and asking
  // pacman again to answer a question about what it just said would be slower
  // and no truer.
  property string filter: "all"

  readonly property var shown: {
    var out = []
    for (var i = 0; i < pending.length; i++) {
      var p = pending[i]
      if (filter === "explicit" && p.explicit !== true) continue
      if (filter === "aur" && p.foreign !== true) continue
      out.push(p)
    }
    return out
  }

  readonly property real shownBytes: {
    var total = 0
    for (var i = 0; i < shown.length; i++)
      if (shown[i].bytes !== null && shown[i].bytes !== undefined) total += Number(shown[i].bytes)
    return total
  }

  // A kernel update is the one that changes what happens at the next boot, so
  // it is worth saying out loud rather than leaving in row 87 of a table.
  readonly property bool kernelWaiting: {
    for (var i = 0; i < pending.length; i++)
      if (String(pending[i].name).indexOf("linux") === 0) return true
    return false
  }

  property int selectedPackage: -1

  readonly property string headerNote: app.packages.installed !== undefined
    ? app.packages.installed + " installed · "
      + (pending.length === 0 ? "nothing waiting" : pending.length + " waiting")
    : ""

  property Component headerControl: Component {
    Ui.Chip {
      text: app.packagesSyncing ? "Checking…" : "Check for updates"
      onClicked: app.refreshPackages()
    }
  }

  // Counts come off the local database and cost nothing; the pending list is
  // whatever the last sync left behind. So this polls, and syncing is a button.
  Timer {
    interval: 10000
    running: app.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: app.pollPackages()
  }

  Ui.SettingGroup {
    framed: false

    RowLayout {
      width: parent.width
      spacing: Style.space(12)

      Ui.StatCard {
        Layout.fillWidth: true
        label: "Installed"
        value: app.packages.installed !== undefined ? String(app.packages.installed) : "—"
      }

      Ui.StatCard {
        Layout.fillWidth: true
        label: "Asked for"
        value: app.packages.explicit !== undefined ? String(app.packages.explicit) : "—"
        // "Explicit" is pacman's word for it, and it means nothing to anyone
        // who has not read pacman's manual.
        note: "The rest came in as dependencies"
      }

      Ui.StatCard {
        Layout.fillWidth: true
        label: "From the AUR"
        value: app.packages.foreign !== undefined ? String(app.packages.foreign) : "—"
      }

      Ui.StatCard {
        Layout.fillWidth: true
        label: "Waiting"
        value: String(pending.length)
        note: shownBytes > 0 ? app.formatBytes(shownBytes) + " to download" : ""
      }
    }
  }

  Ui.SettingGroup {
    title: "Waiting to update"
    note: checkedAt > 0
      ? "Mirrors last checked " + app.formatWhen(checkedAt)
      : "Mirrors have not been checked yet — nothing below is known to be current."
    framed: false

    Row {
      spacing: Style.space(8)

      Repeater {
        model: [
          { id: "all", title: "All" },
          { id: "explicit", title: "Asked for" },
          { id: "aur", title: "AUR" }
        ]

        Ui.Chip {
          required property var modelData
          text: modelData.title
          on: filter === modelData.id
          onClicked: { filter = modelData.id; selectedPackage = -1 }
        }
      }
    }

    Ui.DataTable {
      columns: [
        { title: "Package", weight: 2.2 },
        { title: "Installed", weight: 1.6 },
        { title: "Available", weight: 1.6 },
        { title: "Size", weight: 1, align: "right" },
        { title: "From", weight: 0.9 }
      ]
      currentRow: selectedPackage
      emptyNote: checkedAt > 0 ? "Nothing waiting." : "Check for updates to see what is waiting."
      rows: {
        var out = []
        for (var i = 0; i < shown.length; i++) {
          var p = shown[i]
          out.push({ cells: [
            { text: p.name, strong: true },
            { text: p.installed },
            { text: p.available, strong: true },
            { text: p.bytes !== null && p.bytes !== undefined ? app.formatBytes(p.bytes) : "",
              align: "right" },
            { text: p.foreign === true ? "AUR" : "repo" }
          ] })
        }
        return out
      }
      onActivated: function(index) { selectedPackage = index }
    }

    Row {
      spacing: Style.space(8)

      Ui.Chip {
        text: "Update everything"
        on: true
        onClicked: { app.run(["packages", "update"]); app.hide() }
      }

      // Offered beside the plain update rather than buried, because it is the
      // one thing that makes a bad update recoverable.
      Ui.Chip {
        text: "Snapshot first, then update"
        onClicked: { app.run(["packages", "snapshot-update"]); app.hide() }
      }

      Ui.Chip {
        text: "Refresh mirrors"
        onClicked: { app.run(["packages", "mirrors"]); app.hide() }
      }
    }

    Ui.ReadingRow {
      visible: kernelWaiting
      label: "A kernel update is waiting"
      description: "The running kernel stays until you reboot, and modules built for it stop matching."
    }
  }

  Ui.SettingGroup {
    title: "Housekeeping"

    // The size goes in the note rather than in a tag of its own: a row with a
    // value *and* a button needs the two placed against each other, and the
    // only way to do that here was a hardcoded margin that any change to the
    // button's text would have broken.
    Ui.ActionRow {
      label: "Package cache"
      description: (app.packages.cacheBytes !== null && app.packages.cacheBytes !== undefined
                    ? app.formatBytes(app.packages.cacheBytes) + " in " : "")
        + "/var/cache/pacman/pkg — every version ever downloaded, kept for downgrades."
      buttonText: "Keep last two"
      onTriggered: { app.run(["packages", "clean"]); app.hide() }
    }

    Ui.ActionRow {
      visible: app.packages.orphans > 0
      label: app.packages.orphans === 1 ? "1 orphan" : app.packages.orphans + " orphans"
      description: "Installed as dependencies, and nothing depends on them any more."
      buttonText: "Review"
      onTriggered: { app.run(["packages", "orphans"]); app.hide() }
    }

    Ui.ReadingRow {
      visible: app.packages.foreign > 0
      label: "Foreign packages"
      description: "Not in any configured repository — built from the AUR, or installed by hand."
      value: String(app.packages.foreign)
    }

    Ui.ActionRow {
      visible: app.packages.pacnew > 0
      label: app.packages.pacnew === 1 ? "1 pacnew file" : app.packages.pacnew + " pacnew files"
      description: "Config changes pacman would not apply over your edits, waiting to be merged."
      buttonText: "Merge"
      onTriggered: { app.run(["packages", "pacnew"]); app.hide() }
    }
  }

  Ui.SettingGroup {
    title: "Recently"
    note: "One line per transaction, from pacman's own log."
    visible: !searchEmpty && app.packages.history !== undefined
      && app.packages.history.length > 0

    Ui.DataTable {
      columns: [
        { title: "What", weight: 3 },
        { title: "When", weight: 1.4, align: "right" }
      ]
      rows: {
        var out = []
        var items = app.packages.history !== undefined ? app.packages.history : []
        for (var i = 0; i < items.length; i++) {
          var h = items[i]
          var verb = String(h.verb).charAt(0).toUpperCase() + String(h.verb).slice(1)
          var what = h.count > 1 ? verb + " " + h.count + " packages" : verb + " " + h.name
          out.push({ cells: [
            { text: what, strong: true },
            { text: String(h.at).replace("T", " "), align: "right" }
          ] })
        }
        return out
      }
    }

    Ui.Chip {
      text: "Open pacman.log"
      onClicked: { app.run(["packages", "log"]); app.hide() }
    }
  }
}
