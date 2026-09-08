import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// What this machine is. Every line is a reading; the only thing the page
// writes is the release channel, and that goes through Omarchy's own command
// and its confirmation.
//
// It exists because the answers are otherwise scattered across four tools and
// because the moment anyone needs them — filing a bug — is the moment they
// least want to go looking. Hence "Copy as text": the whole page as one block,
// in the shape a bug report wants.
Ui.SectionBody {
  property var app: null

  readonly property var about: app.about
  readonly property var gpus: about.gpus !== undefined ? about.gpus : []

  readonly property string headerNote: about.version !== undefined && about.version !== ""
    ? "Omarchy " + about.version
      + (about.channel !== "" ? " · " + about.channel + " channel" : "") : ""

  property Component headerControl: Component {
    Ui.Chip {
      text: "Copy as text"
      onClicked: app.run(["about", "copy"])
    }
  }

  // Read once when the page opens. None of it changes while you look at it
  // except the uptime, and a page that re-read a hardware inventory every five
  // seconds to move one number would be absurd.
  Component.onCompleted: app.pollAbout()

  Ui.SettingGroup {
    title: "Hardware"

    Ui.ReadingRow {
      label: "Model"
      value: (about.model !== undefined ? about.model : "")
        + (about.sku !== undefined && about.sku !== "" ? " (" + about.sku + ")" : "")
    }

    Ui.ReadingRow {
      label: "CPU"
      description: about.cpuCores !== null && about.cpuCores !== undefined
        ? about.cpuCores + " cores · " + about.cpuThreads + " threads"
          + (about.cpuFrequency ? " · up to " + (Number(about.cpuFrequency) / 1000).toFixed(2) + " GHz" : "")
        : ""
      value: about.cpu !== undefined ? about.cpu : ""
    }

    // Plural on purpose: a laptop with switchable graphics has two, and
    // calling one of them "the" GPU is how a bug report ends up describing the
    // wrong one.
    Ui.ReadingRow {
      visible: gpus.length > 0
      label: gpus.length > 1 ? "GPUs" : "GPU"
      value: gpus.join(" · ")
    }

    Ui.ReadingRow {
      visible: about.memoryBytes !== null && about.memoryBytes !== undefined
      label: "Memory"
      value: app.formatBytes(about.memoryBytes)
    }

    Ui.ReadingRow {
      visible: about.disk !== undefined && about.disk.size !== null
      label: "Disk"
      value: about.disk !== undefined
        ? about.disk.model + (about.disk.size ? " · " + app.formatBytes(about.disk.size) : "")
        : ""
    }
  }

  Ui.SettingGroup {
    title: "Software"

    Ui.ReadingRow {
      label: "Omarchy"
      description: about.channel === "stable"
        ? "" : "The " + about.channel + " channel takes updates before they reach stable."
      value: about.version !== undefined ? about.version : ""
    }

    Ui.ReadingRow {
      label: "Kernel"
      value: about.kernel !== undefined ? about.kernel : ""
    }

    Ui.ReadingRow {
      label: "Compositor"
      value: about.compositor !== undefined ? about.compositor : ""
    }

    Ui.ReadingRow {
      visible: about.packages !== null && about.packages !== undefined
      label: "Packages"
      value: about.packages + " (pacman)"
    }

    Ui.ReadingRow {
      visible: about.uptimeSeconds !== null && about.uptimeSeconds !== undefined
      label: "Uptime"
      value: app.formatDuration(about.uptimeSeconds)
    }

    // Read off the first line pacman ever wrote, which is the closest thing an
    // Arch install has to a birthday.
    Ui.ReadingRow {
      visible: about.osAgeDays !== null && about.osAgeDays !== undefined
      label: "Installed"
      description: "Dated from the first line in pacman's log."
      value: about.osAgeDays + " days ago"
    }
  }

  Ui.SettingGroup {
    title: "Updates"

    Ui.ReadingRow {
      visible: about.lastUpdate !== undefined && about.lastUpdate !== ""
      label: "Last updated"
      value: about.lastUpdate !== undefined ? about.lastUpdate : ""
    }

    // Three short names, so all three are on screen. A button that cycled
    // through them would make the reader press it twice to find out what the
    // options were, and land them on `dev` on the way past.
    Ui.ChoiceRow {
      label: "Release channel"
      description: "Which stream this machine takes updates from. Later channels get changes sooner, and get them less tested."
      options: ["stable", "rc", "dev"]
      value: about.channel !== undefined ? about.channel : ""
      // Changing it changes what every future update pulls, so it goes to
      // Omarchy's own command and its confirmation rather than being applied
      // from here.
      onPicked: function(next) {
        if (next === about.channel) return
        app.run(["about", "channel", next])
        app.hide()
      }
    }
  }
}
