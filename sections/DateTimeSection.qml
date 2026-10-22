import QtQuick
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  id: page
  property var app: null
  Ui.SettingGroup {
    title: "Clock"

    Ui.ActionRow {
      label: "Timezone"
      description: page.app.datetime.timezone ? String(page.app.datetime.timezone) : "Unknown"
      buttonText: "Change…"
      onTriggered: page.app.run(["menu", "run", "update.timezone"])
    }

    Ui.ActionRow {
      label: "System time"
      description: (page.app.datetime.now ? String(page.app.datetime.now) : "")
        + (page.app.datetime.ntp === true
           ? (page.app.datetime.synchronized === true ? " · synchronized" : " · syncing")
           : " · automatic sync off")
      buttonText: "Resync…"
      onTriggered: page.app.run(["menu", "run", "update.time"])
    }
  }
}
