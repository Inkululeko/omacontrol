import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
//
// The page the window opens on, and the only one that is not about a subject.
// It answers three questions in the order they are asked: is anything wrong,
// what do I flip several times a day, and what did I come here to start.
//
// Nothing here is a setting of its own. Every switch is Omarchy's, every
// notice points at the page that can actually fix it, and both are shown
// rather than kept — so this page cannot disagree with the bar.
Ui.SectionBody {
  property var app: null

  readonly property var toggles: app.overview.toggles !== undefined ? app.overview.toggles : []

  readonly property var toggleGlyphs: ({
    "nightlight": "\uf186",
    "dnd": "\uf1f6",
    "awake": "\uf0f4",
    "dictation": "\uf130"
  })

  // Mostly the reader's, plus the one thing the window already knows about
  // itself. Nothing here re-reads what it is already holding.
  readonly property var updates: app.overview.updates !== undefined ? app.overview.updates : ({})
  readonly property var news: app.overview.news !== undefined ? app.overview.news : ({})
  readonly property var newsItems: news.items !== undefined ? news.items : []
  readonly property int unreadNews: {
    var n = 0
    for (var i = 0; i < newsItems.length; i++) if (newsItems[i].read === false) n++
    return n
  }
  readonly property var updatePlugins: updates.plugins !== undefined ? updates.plugins : []
  readonly property bool hasUpdates: (updates.omarchy !== undefined && updates.omarchy !== null)
    || updates.packages > 0 || updatePlugins.length > 0

  readonly property var attention: {
    var items = []
    var reported = app.overview.attention !== undefined ? app.overview.attention : []
    for (var i = 0; i < reported.length; i++) items.push(reported[i])

    if (app.selfBehind > 0)
      items.push({
        id: "self",
        title: "OmaControl is " + app.selfBehind
          + (app.selfBehind === 1 ? " commit behind" : " commits behind"),
        note: "Checked once this opening.",
        actionLabel: "Update",
        update: true
      })

    return items
  }

  readonly property string headerNote: attention.length === 0 ? ""
    : (attention.length === 1 ? "1 thing needs attention"
                              : attention.length + " things need attention")

  // Switch state is held in the running system — hyprsunset's temperature, the
  // shell's own do-not-disturb — so it can be changed from the bar or a
  // keybinding while this page is on screen. Polling is how the page agrees
  // with them rather than arguing.
  Timer {
    interval: 5000
    running: app.shown
    repeat: true
    triggeredOnStart: true
    onTriggered: app.pollOverview()
  }

  // The one thing in this window that leaves the machine, and the *cache's
  // age* decides whether it happens — not the page, and not the reader. A
  // fetch that finds the cache under half an hour old does nothing at all, so
  // asking on open and again on a timer costs nothing but catches the case
  // this is for: a window left open all afternoon.
  Component.onCompleted: app.fetchNews()

  Timer {
    interval: 1800000
    running: app.shown
    repeat: true
    onTriggered: app.fetchNews()
  }

  // First, and tiles across rather than rows down, with no heading over them.
  // They are the strip of chrome the page opens with rather than a section of
  // it: the question they
  // answer is *which of these are on*, asked of all four at once, and a filled
  // tile answers it from across the room where four knobs in a line do not.
  Ui.SettingGroup {
    // The tiles are the cards.
    Grid {
      id: toggleGrid
      width: parent.width
      columns: 4
      spacing: Style.space(10)

      Repeater {
        model: toggles

        Ui.ToggleTile {
          required property var modelData

          // Grid does not stretch what it lays out, so a tile is told its
          // share of the row.
          width: (toggleGrid.width - (toggleGrid.columns - 1) * toggleGrid.spacing)
            / toggleGrid.columns
          glyph: toggleGlyphs[modelData.id] !== undefined ? toggleGlyphs[modelData.id] : ""
          label: modelData.label
          note: modelData.note !== undefined ? modelData.note : ""
          checked: modelData.on === true
          // The command that owns the switch is the one that flips it, side
          // effects and all — starting hyprsunset, telling the bar to redraw.
          // Then the page asks again rather than assuming it worked.
          onRequested: {
            app.run(["overview", "toggle", modelData.id])
          }
        }
      }
    }
  }

  // Anything the reader would want to know before they got to whatever they
  // opened the window for. Gone entirely when there is nothing, heading and
  // all — not replaced by a note saying so. A section that reports its own
  // emptiness takes up room on every good day to reassure the reader on none
  // of them, and the page says it better by its absence: with nothing wrong,
  // the toggles run straight into the updates.
  Ui.SettingGroup {
    framed: true
    title: "Needs attention"
    visible: !searchEmpty && attention.length > 0

    Repeater {
      model: attention

      Ui.NoticeRow {
        required property var modelData

        label: modelData.title
        description: modelData.note !== undefined ? modelData.note : ""
        glyph: modelData.urgent === true ? "\uf071" : "\uf05a"
        urgent: modelData.urgent === true
        actionText: modelData.actionLabel !== undefined ? modelData.actionLabel : "Open"
        dismissable: modelData.id !== undefined

        onTriggered: {
          if (modelData.update === true) {
            if (app.selfId !== "") app.run(["plugin", "update", app.selfId])
          } else if (modelData.page !== undefined) {
            app.pageId = modelData.page
          } else if (modelData.action !== undefined) {
            app.pageId = modelData.action
          }
        }

        onDismissed: {
          app.run(["overview", "dismiss", modelData.id])
        }
      }
    }
  }

  // What is waiting, from three caches and no network. The note says when the
  // package list was last synced, because a count of updates is meaningless
  // without knowing how old it is.
  Ui.SettingGroup {
    framed: true
    title: "Updates"
    note: updates.checkedAt > 0
      ? "Mirrors last checked " + app.formatWhen(updates.checkedAt)
      : "Mirrors have not been checked yet."
    visible: !searchEmpty && hasUpdates

    // Omarchy ships as a package, so its row is that package pulled out of
    // the list and named as the thing the reader actually thinks about.
    Ui.NoticeRow {
      visible: !searchHidden && updates.omarchy !== undefined && updates.omarchy !== null
      glyph: ""
      label: updates.omarchy ? "Omarchy " + updates.omarchy.available : ""
      description: "You are on " + updates.version
        + (updates.channel !== "" ? " · " + updates.channel + " channel" : "")
      actionText: "Update"
      onTriggered: { app.run(["packages", "update"]); app.hide() }
    }

    Ui.NoticeRow {
      visible: !searchHidden && updates.packages > 0
      glyph: ""
      label: updates.packages === 1 ? "1 package" : updates.packages + " packages"
      description: "Waiting in the repositories and the AUR."
      actionText: "Open Packages"
      onTriggered: app.pageId = "packages"
    }

    Ui.NoticeRow {
      visible: !searchHidden && updatePlugins.length > 0
      glyph: ""
      label: updatePlugins.length === 1 ? "1 plugin" : updatePlugins.length + " plugins"
      description: updatePlugins.join(" · ")
      actionText: "Open Plugins"
      onTriggered: app.pageId = "plugins"
    }
  }

  // The only thing in this window that comes off the network. It is last
  // because it is the only thing on the page that is not about this machine.
  Ui.SettingGroup {
    framed: true
    title: "News from omarchy.org"
    // The count first, because it is the only part of this heading anyone
    // scans for; the age second, because a headline with no age on it is one
    // you cannot judge.
    note: (unreadNews > 0 ? (unreadNews === 1 ? "1 new · " : unreadNews + " new · ") : "")
      + (news.fetchedAt !== undefined && news.fetchedAt > 0
         ? "fetched " + app.formatWhen(news.fetchedAt) : "")
    visible: !searchEmpty && newsItems.length > 0

    Repeater {
      model: newsItems.slice(0, 5)

      // A headline is a link, so the whole row is one. A Read button beside
      // each of five rows is five buttons doing what clicking the headline
      // already does, and they out-weigh everything above them on the page.
      Ui.LinkRow {
        required property var modelData

        label: modelData.title
        // What the site itself printed, rather than a date reformatted into
        // something its author would not recognise.
        value: modelData.shown !== undefined ? modelData.shown : ""
        unread: modelData.read === false
        // Opening one reads it — the reader does not have to say so twice —
        // and `news open` records that itself, so both paths agree.
        //
        // Then this window gets out of the way. It takes keyboard focus
        // exclusively while it is open, so leaving it up means the article you
        // just asked for is behind a settings window you have to dismiss.
        // `news open` follows the browser to its workspace from its side.
        onTriggered: { app.run(["news", "open", modelData.url]); app.hide() }
        onStarred: app.run(["news", "read", modelData.url])
      }
    }

    Ui.Chip {
      visible: unreadNews > 0
      text: "Mark all as read"
      onClicked: app.run(["news", "read-all"])
    }
  }
}
