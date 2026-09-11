import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  id: page
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

  // The state a battery is in, as one thing rather than as seven rows of a
  // name and a number. It is the same shape the Network page gives the
  // connection you are on, and for the same reason: these are facts about one
  // object, and a column of rows asks the reader to read every name to find
  // the one they came for.
  // Two questions, two answers, and they are not the same question — which is
  // exactly what one merged line hid. Where the power comes from is UPower's
  // OnBattery; what the pack is doing about it is the battery's own state,
  // and a docked laptop at 100% commonly reports `discharging` while it
  // trickles a few tenths of a watt out. Said as one sentence that reads as a
  // contradiction; said as two, it is simply the truth twice.
  readonly property string sourceLabel: onBattery ? "On battery" : "Plugged in"
  readonly property string stateLabel: {
    var state = String(reading.state || "")
    if (state === "charging" || state === "pending-charge") return "Charging"
    if (state === "discharging" || state === "pending-discharge") return "Discharging"
    if (state === "fully-charged") return "Fully charged"
    if (state === "empty") return "Empty"
    return state
  }

  // Charging is the only one of the three that is something happening rather
  // than something being the case, so it is the only one drawn in the accent.
  readonly property bool stateIsAccented: String(reading.state || "") === "charging"

  // The bar's own ten-step battery set, and its charging bolt — the same
  // glyphs the power widget draws, so a laptop reads the same on the page as
  // it does in the corner of the screen.
  readonly property var levelGlyphs: ["\udb80\udc7a", "\udb80\udc7b", "\udb80\udc7c", "\udb80\udc7d",
                                      "\udb80\udc7e", "\udb80\udc7f", "\udb80\udc80", "\udb80\udc81",
                                      "\udb80\udc82", "\udb80\udc79"]
  readonly property string chargingGlyph: "\udb80\udc84"

  // Whether the machine is running off the battery, which is the first thing
  // anyone opening this page wants to know and the one thing a percentage on
  // its own does not say.
  readonly property bool onBattery: power.onBattery === true
  readonly property string batteryGlyph: onBattery
    ? levelGlyphs[Math.max(0, Math.min(9, Math.floor(Number(reading.percentage || 0) / 10)))]
    : chargingGlyph

  // What is left over once the two pills have said the state: how long, and
  // how fast. An estimate of how long the battery lasts is about running on
  // it, so on the mains it is an answer to a question nobody asked.
  readonly property string batterySummary: {
    var parts = []
    var left = String(reading.remaining || "")
    if (left !== "" && (onBattery || reading.state === "charging"))
      parts.push(reading.state === "charging" ? left + " until full" : left + " left")
    if (reading.watts !== null && reading.watts !== undefined)
      parts.push(Number(reading.watts).toFixed(1) + " W")
    return parts.join("  ·  ")
  }

  readonly property var batteryFacts: {
    var out = [
      // Four figures that are only useful as a sequence: what is in the pack,
      // what the pack holds when it is full, what it was sold as holding, and
      // the last two compared. The labels carry that, because on a full
      // battery the first two are the same number and a reader with no way to
      // tell them apart concludes the card is repeating itself.
      { key: "stored", label: "In it now" },
      { key: "full", label: "When full, today" },
      { key: "rated", label: "Maker's rating" },
      { key: "health", label: "Health" },
      { rule: true },
      { key: "cycles", label: "Charge cycles", small: true }
    ]
    // Only ever on a bad day: UPower answers "none" the rest of the time, and
    // a cell reading "Warning: none" trains people not to read it.
    if (String(reading.warning || "") !== "")
      out.push({ key: "warning", label: "Warning", small: true })
    return out
  }

  readonly property var batteryValues: {
    var levels = { "low": "Low", "critical": "Critical", "action": "About to shut down" }
    var warning = String(reading.warning || "")
    return {
      stored: reading.energy > 0 ? Number(reading.energy).toFixed(1) + " Wh" : "—",
      health: reading.health !== null && reading.health !== undefined
        ? reading.health + "% of rated" : "—",
      full: reading.energyFull > 0 ? Number(reading.energyFull).toFixed(1) + " Wh" : "—",
      // Makers rate conservatively and the gauge recalibrates as it learns
      // the pack, so a healthy battery measures a little above this.
      rated: reading.energyDesign > 0 ? Number(reading.energyDesign).toFixed(1) + " Wh" : "—",
      cycles: reading.cycles !== null && reading.cycles !== undefined
        ? String(reading.cycles) : "Not counted",
      warning: levels[warning] !== undefined ? levels[warning] : warning
    }
  }

  Ui.SettingGroup {
    framed: true
    visible: !searchEmpty && power.hasBattery === true

    Item {
      width: parent.width
      implicitHeight: identity.implicitHeight

      Text {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: page.batteryGlyph
        color: page.onBattery ? Ui.Palette.foreground : Ui.Palette.accent
        font.family: Ui.Palette.fontFamily
        font.pixelSize: Style.font.display
      }

      Column {
        id: identity
        anchors.left: glyph.right
        anchors.leftMargin: Style.space(12)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
          width: parent.width
          text: reading.percentage !== null && reading.percentage !== undefined
            ? reading.percentage + "%" : "\u2014"
          elide: Text.ElideRight
          color: Ui.Palette.foreground
          font.family: Ui.Palette.fontFamily
          font.pixelSize: Style.font.heading
          font.bold: true
        }

        // The two states as pills rather than as words in a sentence: these
        // are the two facts anyone opens this page for, and a reader should
        // not have to parse a comma to get them.
        Row {
          spacing: Style.space(6)

          Ui.Tag {
            visible: page.stateLabel !== ""
            text: page.stateLabel
            accented: page.stateIsAccented
          }

          Ui.Tag {
            text: page.sourceLabel
            // The plug is the fact about the desk rather than about the
            // pack, and it is never the alarming one.
            accented: false
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: page.batterySummary !== ""
            text: page.batterySummary
            color: Ui.Palette.muted
            font.family: Ui.Palette.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }
    }

    Ui.FactGrid {
      layout: page.batteryFacts
      values: page.batteryValues
    }

    // The one line these four cells cannot say for themselves: which of them
    // moves, which is learned, and which was only ever printed. Without it a
    // full battery shows the same number twice and a rating it appears to
    // beat, and the honest conclusion from that is that the card is wrong.
    // Inside the card, because it is about these cells and not about the page.
    Text {
      width: parent.width
      text: "In it now changes as you use it. When full is what the battery holds today, which its gauge re-learns as the cells age. The maker's rating is printed rather than measured, and printed low — so Health, which is those two compared, stops at 100% even when the battery holds more."
      wrapMode: Text.WordWrap
      color: Ui.Palette.muted
      font.family: Ui.Palette.fontFamily
      font.pixelSize: Style.font.caption
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
