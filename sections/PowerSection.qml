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
  // Where the power is coming from, which is UPower's question to answer and
  // not the battery's: a docked laptop at 100% often trickles a few tenths of
  // a watt *out* of the pack, so the battery calls itself discharging while
  // the machine is plainly on the mains. The icon and this line read the same
  // property, or the page shows a plug beside the words "on battery".
  readonly property string stateLabel: {
    if (onBattery) return "On battery"
    var state = String(reading.state || "")
    if (state === "charging" || state === "pending-charge") return "Charging"
    if (state === "fully-charged") return "Plugged in, fully charged"
    return "Plugged in"
  }

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

  readonly property string batterySummary: {
    var parts = []
    if (stateLabel !== "") parts.push(stateLabel)
    // An estimate of how long the battery lasts is about running on it. On
    // the mains it is an answer to a question nobody asked.
    var left = String(reading.remaining || "")
    if (left !== "" && (onBattery || reading.state === "charging"))
      parts.push(reading.state === "charging" ? left + " until full" : left + " left")
    if (reading.watts !== null && reading.watts !== undefined)
      parts.push(Number(reading.watts).toFixed(1) + " W")

    return parts.join("  ·  ")
  }

  readonly property var batteryFacts: {
    var out = [
      // What is in the pack right now, which the percentage above answers as
      // a share and this answers as an amount — the one that can be held
      // against a charger, a power bank, or how long a flight is.
      { key: "stored", label: "Stored now" },
      // Then what a full charge comes to, what the maker rates it at, and
      // health, which is the first over the second. As one cell it read
      // "61.8 Wh, rated 60.6 Wh" — a battery holding more than it did new,
      // which is not a thing that happens; it is the rating that is low.
      { key: "full", label: "Full charge" },
      { key: "rated", label: "Rated" },
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

        Text {
          width: parent.width
          text: page.batterySummary
          elide: Text.ElideRight
          color: Ui.Palette.muted
          font.family: Ui.Palette.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Ui.FactGrid {
      layout: page.batteryFacts
      values: page.batteryValues
    }

    // The one line these four cells cannot say for themselves. Rated is a
    // number printed on the pack rather than a measurement of it, makers
    // print it low, and the gauge recalibrates as it learns the cells — so a
    // healthy battery reads *above* its rating and the reader is left with a
    // full charge that looks impossible and a health figure that looks stuck.
    // Inside the card, because it is about these cells and not about the page.
    Text {
      width: parent.width
      text: "Rated is what the maker prints on the pack, not a measurement. They print it low, so a healthy battery often holds more than that — and Health stops at 100% when it does."
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
