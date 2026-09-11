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

    // Which of the three things a battery can be doing. The row below says
    // how long it has left, which on a full battery on the mains is nothing
    // at all — leaving the group with a percentage and no account of it.
    Ui.ReadingRow {
      label: "State"
      visible: !searchHidden && String(reading.state || "") !== ""
      value: {
        var states = {
          "charging": "Charging",
          "discharging": "On battery",
          "fully-charged": "Fully charged",
          "pending-charge": "Waiting to charge",
          "pending-discharge": "Waiting to discharge",
          "empty": "Empty"
        }
        var state = String(reading.state || "")
        return states[state] !== undefined ? states[state] : state
      }
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

    // The two figures that percentage is computed from, and the ones to hold
    // against the spec of a replacement.
    Ui.ReadingRow {
      label: "Capacity"
      visible: !searchHidden && reading.energyFull > 0 && reading.energyDesign > 0
      value: Number(reading.energyFull).toFixed(1) + " Wh, "
        + Number(reading.energyDesign).toFixed(1) + " Wh when new"
    }

    // The other half of "is this battery worn out", and not every firmware
    // counts them — so the row goes rather than reporting that it cannot say.
    Ui.ReadingRow {
      label: "Charge cycles"
      visible: !searchHidden && reading.cycles !== null && reading.cycles !== undefined
      value: String(reading.cycles)
    }

    // Only ever on a bad day: UPower says "none" the rest of the time, and a
    // row that reads "Warning: none" trains people not to read it.
    Ui.ReadingRow {
      label: "Warning"
      visible: !searchHidden && String(reading.warning || "") !== ""
      value: {
        var levels = { "low": "Low", "critical": "Critical", "action": "About to shut down" }
        var level = String(reading.warning || "")
        return levels[level] !== undefined ? levels[level] : level
      }
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
