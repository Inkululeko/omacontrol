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

  readonly property string sourceLabel: onBattery ? "On battery" : "Plugged in"

  // On the mains the battery's own word for itself is not a state anyone
  // recognises: a full pack on a dock reports `discharging` while it trickles
  // a few hundredths of a watt out, so the card read "100% Discharging" on a
  // laptop that was plainly done charging. What the reader means by the
  // question is whether energy is going in, and on the mains that is answered
  // by the charge rather than by the flag — full is full, and anything short
  // of it with nothing going in is a battery being held there, which is what
  // a charge limit does.
  readonly property string stateLabel: {
    var state = String(reading.state || "")
    var percentage = Number(reading.percentage || 0)
    if (state === "empty") return "Empty"
    if (onBattery) return state === "discharging" || state === "pending-discharge"
      ? "Discharging" : "On battery"
    if (state === "charging" || state === "pending-charge") return "Charging"
    if (state === "fully-charged" || percentage >= 99) return "Fully charged"
    return "Not charging"
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

  // Under the headline: how long it has at this rate. An estimate of how long
  // the battery lasts is about running on it, so on the mains it answers a
  // question nobody asked — and how fast it is going is a reading like the
  // others, so it sits with them rather than in the headline.
  readonly property string batterySummary: {
    var parts = []
    var left = String(reading.remaining || "")
    if (left !== "" && (onBattery || reading.state === "charging"))
      parts.push(reading.state === "charging" ? left + " until full" : left + " left")
    return parts.join("  ·  ")
  }

  // Red, amber, green, on the thresholds a battery indicator has always used:
  // under a fifth left is the one worth a colour that alarms, under a half is
  // worth noticing, and the rest is fine. Charging is green whatever the
  // level, because the number is on its way up and a red icon over a battery
  // that is filling is a warning about nothing.
  readonly property color levelColor: {
    if (!onBattery || reading.state === "charging") return Ui.Palette.good
    var percentage = Number(reading.percentage || 0)
    if (percentage <= 20) return Ui.Palette.bad
    if (percentage <= 50) return Ui.Palette.caution
    return Ui.Palette.good
  }

  readonly property var batteryFacts: {
    var out = [
      // What the battery is doing this minute: how much is in it, and how
      // fast that is moving. The rate is named for what is happening to it —
      // power going out is being used, power going in is charging — and on a
      // full battery on the mains nothing is happening to it at all, so the
      // cell goes rather than reporting a nought under a word for movement.
      { key: "stored", label: "In it now" }
    ]
    if (page.onBattery) out.push({ key: "rate", label: "Using now" })
    else if (String(reading.state || "") === "charging")
      out.push({ key: "rate", label: "Charging at" })
    out = out.concat([
      { rule: true },
      // Then the pack's life, which is three figures only useful as a
      // sequence: what it holds when full, what it was sold as holding, and
      // the two compared. The labels carry that, because on a full battery
      // the first of them equals "In it now" above, and a reader with no way
      // to tell them apart concludes the card is repeating itself.
      { key: "full", label: "When full, today", small: true },
      { key: "rated", label: "Rated capacity", small: true },
      { key: "health", label: "Health", small: true },
      { key: "cycles", label: "Charge cycles", small: true }
    ])
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
      // Zero while a full battery sits on the mains, which is the truth: no
      // energy is going either way.
      rate: reading.watts !== null && reading.watts !== undefined
        ? Number(reading.watts).toFixed(1) + " W" : "—",
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
      implicitHeight: Math.max(glyph.implicitHeight, identity.implicitHeight, source.implicitHeight)

      // Big, and coloured by how much is left: the one thing on this page
      // that should be readable from across the desk, and the reason the
      // percentage below it can be a quiet line rather than a headline.
      Text {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: page.batteryGlyph
        color: page.levelColor
        font.family: Ui.Palette.fontFamily
        font.pixelSize: Style.font.displayLarge * 1.6
      }

      Column {
        id: identity
        anchors.left: glyph.right
        anchors.leftMargin: Style.space(14)
        anchors.right: source.left
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        // "100% Fully charged" as one line, the number carrying it. A
        // percentage is what the reader is here for and it is the thing they
        // can take in without reading — so it is the size of the headline,
        // and the words sit on its baseline rather than above or below it.
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            id: level
            text: reading.percentage !== null && reading.percentage !== undefined
              ? reading.percentage + "%" : "\u2014"
            color: Ui.Palette.foreground
            font.family: Ui.Palette.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
          }

          Text {
            anchors.baseline: level.baseline
            text: page.stateLabel
            elide: Text.ElideRight
            color: Ui.Palette.muted
            font.family: Ui.Palette.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }
        }

        Text {
          width: parent.width
          visible: page.batterySummary !== ""
          text: page.batterySummary
          elide: Text.ElideRight
          color: Ui.Palette.muted
          font.family: Ui.Palette.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      // Where the power comes from is a different question from what the pack
      // is doing — a docked laptop at 100% reports discharging while plainly
      // on the mains — so it is a badge of its own rather than another clause.
      Ui.Tag {
        id: source
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: page.sourceLabel
        accented: !page.onBattery
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
      text: "In it now changes as you use it. When full is what the battery holds today, which its gauge re-learns as the cells age. Rated capacity is what the maker printed on the pack rather than anything measured, and they print it low — so Health, which is those two compared, stops at 100% even when the battery holds more."
      wrapMode: Text.WordWrap
      color: Ui.Palette.muted
      font.family: Ui.Palette.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  // Under the battery rather than on the Processes page as well, because the
  // question "what is draining it" is asked here, on the page that says how
  // long is left.
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
