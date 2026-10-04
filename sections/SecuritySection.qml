import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// What can reach this machine, and how you sign in to it. Nothing here is
// written by this window. The firewall is read, never changed: that takes
// root, and Omarchy has no command of its own to hand it to. The ways of
// signing in are Omarchy's own setup and remove scripts, which edit PAM and
// ask for a password in a terminal of their own.
//
// The table exists for one question nothing else on the desktop answers: is
// anything still behind the ports that were opened? A rule outlives the
// program it was opened for, and a port open to the network with nothing
// listening is a door left unlocked for whatever listens there next. Omarchy's
// own SSH removal closes `limit 22/tcp` and nothing else, so a port 22 opened
// any other way is exactly the rule that stays behind.
Ui.SectionBody {
  property var app: null

  readonly property var security: app.security
  readonly property var rules: security.rules !== undefined ? security.rules : []
  readonly property var signIn: security.signIn !== undefined ? security.signIn : ({})
  readonly property bool polled: security.installed !== undefined
  readonly property bool firewallOn: security.enabled === true
  readonly property bool letsAllIn: security.incoming === "ACCEPT"
  readonly property string otherFirewall: security.otherFirewall !== undefined ? security.otherFirewall : ""
  readonly property bool showsRules: security.installed === true && (firewallOn || otherFirewall === "")

  function way(id) {
    return signIn[id] !== undefined ? signIn[id]
      : ({ available: false, active: false, canSetup: false, canRemove: false })
  }

  // The menu entry the button runs, and whether there is one to run.
  function entryFor(id) { return (way(id).active ? "remove" : "setup") + ".security." + id }
  function canRun(id) { return way(id).active ? way(id).canRemove === true : way(id).canSetup === true }

  // A program that bound the port opens and closes it as it starts and stops,
  // and setting up a way in finishes in a terminal this page cannot watch.
  Timer {
    interval: 5000
    running: app.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: app.pollSecurity()
  }

  // The name a reader knows a port by. Only the ones an Omarchy machine
  // opens or is likely to: anything else is a number the reader opened
  // themselves and already has a name for.
  readonly property var portNames: ({
    "22": "SSH",
    "53": "DNS",
    "80": "Web",
    "443": "Web",
    "53317": "LocalSend"
  })

  function protocols(list) {
    if (list.indexOf("any") !== -1 || list.length > 1) return "TCP + UDP"
    return list.length === 1 ? String(list[0]).toUpperCase() : ""
  }

  function listeningText(rule) {
    if (rule.container === true) return "Container at " + rule.to
    if (rule.by.length > 0) return rule.by.join(", ")
    if (rule.otherUser === true) return "Another user's program"
    if (rule.unnamed === true) return "A system service"
    if (rule.localOnly === true) return "Only this machine"
    return "Nothing"
  }

  Ui.SettingGroup {
    title: "Firewall"
    visible: !searchEmpty && polled

    // What the rules below sit on top of. A firewall that is off, or one
    // whose default lets everything in, makes the list of open ports
    // meaningless, so that is said here rather than under the table.
    Ui.ReadingRow {
      label: "Incoming connections"
      description: {
        if (!firewallOn && otherFirewall !== "") return "Its rules can only be read with an administrator's password."
        if (!firewallOn) return "Every program listening on the network can be reached by anyone on it."
        var parts = []
        if (letsAllIn) parts.push("Anything a rule below does not turn away is let in.")
        if (security.dockerOpen === true)
          parts.push("Ports Docker publishes for its containers are open to the network whatever is listed here.")
        return parts.join(" ")
      }
      value: !firewallOn && otherFirewall !== "" ? "Managed by " + otherFirewall
        : security.installed !== true ? "All · no firewall"
        : !firewallOn ? "All · firewall off"
        : letsAllIn ? "All" : ""
    }

    Ui.DataTable {
      visible: showsRules
      columns: [
        { title: "Port", weight: 1 },
        { title: "For", weight: 1.4 },
        { title: "Protocol", weight: 1 },
        { title: "Allowed from", weight: 1.6 },
        { title: "Listening", weight: 1.4 }
      ]
      emptyNote: security.rulesReadable === false
        ? "The firewall's rules could not be read." : "No ports are open."
      rows: {
        var out = []
        for (var i = 0; i < rules.length; i++) {
          var r = rules[i]
          var from = r.from === "any" ? "Anywhere" : String(r.from)
          if (r.interface !== "") from = r.from === "any" ? "Over " + r.interface : from + " over " + r.interface
          // Rate-limited: six attempts in thirty seconds from one address and
          // the rest are dropped, which is what keeps a password-guesser off.
          if (r.action === "limit") from += ", rate-limited"
          out.push({ cells: [
            { text: r.port === "any" ? "All"
                : String(r.port).replace(/:/g, "\u2013").replace(/,/g, ", "), strong: true },
            { text: r.container === true ? "Container"
                : r.app !== "" ? String(r.app)
                : (portNames[r.port] !== undefined ? portNames[r.port] : ""),
              tag: String(r.comment || "") },
            { text: protocols(r.protos) },
            { text: from },
            { text: listeningText(r) }
          ] })
        }
        return out
      }
    }
  }

  Ui.SettingGroup {
    title: "Signing in"
    visible: !searchEmpty && polled

    // Only where there is a reader: the setup cannot do anything without
    // one, and a row offering it on a desktop is a row that can only fail.
    Ui.ActionRow {
      label: "Fingerprint"
      visible: !searchHidden && (way("fingerprint").available || way("fingerprint").active)
        && (way("fingerprint").canSetup || way("fingerprint").canRemove)
      description: way("fingerprint").active
        ? "Set up · unlocks the screen and approves admin prompts"
        : "Not set up · the reader here can unlock the screen and approve admin prompts"
      buttonText: way("fingerprint").active ? "Remove…" : "Set up…"
      actionEnabled: canRun("fingerprint")
      onTriggered: { app.run(["menu", "run", entryFor("fingerprint")]); app.hide() }
    }

    Ui.ActionRow {
      label: "FIDO2 security key"
      visible: !searchHidden && (way("fido2").canSetup || way("fido2").canRemove)
      description: way("fido2").active
        ? "Set up · a touch of the key approves admin prompts"
        : "Not set up · a touch of a key can approve admin prompts"
      buttonText: way("fido2").active ? "Remove…" : "Set up…"
      actionEnabled: canRun("fido2")
      onTriggered: { app.run(["menu", "run", entryFor("fido2")]); app.hide() }
    }

    // Whether it takes a password is the half that matters: a server that
    // takes keys only cannot be guessed into. When a config file in the way
    // could not be read, the page says the server is on and stops there.
    Ui.ActionRow {
      label: "SSH server"
      visible: !searchHidden && (way("sshd").canSetup || way("sshd").canRemove || way("sshd").active)
      description: !way("sshd").active
        ? "Off · lets another computer sign in to this one with a key you authorize, and opens its port"
        : way("sshd").passwords === false ? "On · accepts sign-ins from authorized keys only"
        : way("sshd").passwords === true ? "On · accepts a password as well as a key"
        : "On · accepts sign-ins from other computers"
      buttonText: way("sshd").active ? "Turn off…" : "Set up…"
      actionEnabled: canRun("sshd")
      onTriggered: { app.run(["menu", "run", entryFor("sshd")]); app.hide() }
    }
  }
}
