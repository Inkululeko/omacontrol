import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  property var app: null

  readonly property var power: app.power
  readonly property var reading: power.battery !== undefined ? power.battery : ({})

  // Power profiles are named for machines, not people. The icons are the
  // bar's own, from its power widget: the same three glyphs for the same
  // three profiles, since the bar is where most people meet them and two
  // pictures for one profile is one too many.
  function profileOptions() {
    var labels = { "power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance" }
    var icons = { "power-saver": "\udb80\udf2a", "balanced": "\udb80\ude9a", "performance": "\udb81\udcc5" }
    var list = power.profiles !== undefined ? power.profiles : []
    var out = []
    for (var i = 0; i < list.length; i++)
      out.push({ value: String(list[i]), label: labels[list[i]] || String(list[i]),
                 icon: icons[list[i]] || "" })
    return out
  }

  Ui.SettingGroup {
    title: "Battery"
    visible: !searchEmpty && power.hasBattery === true

    Ui.ReadingRow {
      label: "Charge"
      value: reading.percentage !== null && reading.percentage !== undefined
        ? reading.percentage + "%" : "—"
    }

    Ui.ReadingRow {
      label: reading.state === "charging" ? "Until full" : "Remaining"
      visible: !searchHidden && reading.remaining !== undefined && String(reading.remaining) !== ""
      value: String(reading.remaining)
    }

    Ui.ReadingRow {
      label: "Drawing"
      visible: !searchHidden && reading.watts !== null && reading.watts !== undefined
      value: Number(reading.watts).toFixed(1) + " W"
    }

    Ui.ReadingRow {
      label: "Health"
      // Wear is the number that decides whether a battery is worth replacing,
      // and nothing else on the desktop shows it.
      visible: !searchHidden && reading.health !== null && reading.health !== undefined
      value: reading.health + "% of when it was new"
    }
  }

  Ui.SettingGroup {
    title: "Profile"

    Ui.ChoiceRow {
      label: "On battery"
      value: power.forBattery !== undefined ? String(power.forBattery) : ""
      options: profileOptions()
      onPicked: function(next) { app.run(["power", "profile", "battery", next]) }
    }

    Ui.ChoiceRow {
      label: "Plugged in"
      value: power.ac !== undefined ? String(power.ac) : ""
      options: profileOptions()
      onPicked: function(next) { app.run(["power", "profile", "ac", next]) }
    }
  }
}
