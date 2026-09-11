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
      // and nothing else on the desktop shows it. It stops at 100 because
      // UPower stops it there, which is worth saying: a reader who works the
      // ratio out from the row below will get 102 and wonder which is wrong.
      description: "A full charge as a share of the rating. It stops at 100%, however far above the rating the battery measures."
      visible: !searchHidden && reading.health !== null && reading.health !== undefined
      value: reading.health + "% of its rated capacity"
    }

    // The two figures health is computed from, and the ones to hold against
    // the spec of a replacement.
    //
    // "when new" was the first wording and it is a thing that cannot be true:
    // the second figure is the manufacturer's rating, not a measurement of
    // the cell when it was new. Vendors rate conservatively and the fuel
    // gauge recalibrates as it learns the pack, so a healthy battery measures
    // a little *above* its rating — and the page was then claiming it held
    // more than it did new.
    Ui.ReadingRow {
      label: "Capacity"
      // The pair is worth showing and worth explaining in the same breath:
      // a first reading of "61.8 Wh, rated 60.6 Wh" is a battery that holds
      // more than it did new, which is not a thing that happens. It is the
      // rating that is low, and knowing that is the difference between the
      // row being useful and the row being alarming.
      description: "What a full charge measures now, against the rating on the pack. Makers rate low, so a healthy battery often measures above it."
      visible: !searchHidden && reading.energyFull > 0 && reading.energyDesign > 0
      value: Number(reading.energyFull).toFixed(1) + " Wh, rated "
        + Number(reading.energyDesign).toFixed(1) + " Wh"
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
