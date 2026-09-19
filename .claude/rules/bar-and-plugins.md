---
paths:
  - "lib/{plugins,shell_config}.sh"
  - "sections/{Bar,Plugins,Idle}Section.qml"
  - "Panel.qml"
  - "Service.qml"
  - "manifest.json"
  - "omacontrol.desktop"
---

# The bar layout, and the plugin the window lives in

> **Read this when:** you touch `lib/plugins.sh`, `lib/shell_config.sh`, `sections/BarSection.qml`, `sections/PluginsSection.qml`, `Service.qml`, `Panel.qml`, `manifest.json` or `omacontrol.desktop`.

## The service owns the window

Omarchy counts a plugin as enabled when its id appears anywhere in
`shell.json` — a `bar.layout` entry or a `plugins[]` entry. When the bar
widget hosted the window, taking the gear out of the bar was the same thing as
uninstalling: the `omacontrol` IPC target answered "Target not found", the
launcher entry was deleted, and a hotkey bound to it stopped working.

So `Service.qml` holds the window, its `Loader` and the `IpcHandler`; the
shell keeps a service alive for as long as the plugin is enabled, however it
was enabled. `Panel.qml` is only the gear: it looks the service up through
`bar.shell.serviceFor()` and forwards to it, keeping `open`/`close`/`opened`
so `Bar.findPanelWidget` still routes `shell summon` through it. One window
also means one window on a two-monitor setup, where each bar instance used to
carry its own.

The shell tears services down on `reloadPlugins()` as well as widgets, so the
Plugins page's summon-back dance below is still needed.

## The launcher entry

The plugin is an app as well as a bar widget: `Service.qml` is also the
`service` entry point that writes `~/.local/share/applications/omacontrol.desktop` from
the template beside it, substituting the icon path, and deletes it again on
disable or remove. Omarchy has no install hook, which is why this lives in the
plugin rather than in a package.

Both halves guard on `X-OmaControl-Managed=true`: a file at that path without
the marker is never written and never deleted, so a hand-written entry
survives. Every failure in the script is a quiet exit — a launcher entry is a
convenience, and none of it is worth interrupting the shell over.

Changing either file means testing the whole cycle, not just the write:
`omarchy plugin disable`, check the file is gone, `omarchy plugin enable`,
check it is back, and `desktop-file-validate` what it wrote.


## The bar layout

`bar move` and `bar shift` edit `.bar.layout` in `shell.json`. Both move the
widget's **whole object**, never rebuild it from its id: a widget keeps its own
settings in that same object, and half the bar would lose its configuration the
first time it was reordered.

**A widget's settings are the keys of its entry beside the id** — the bar hands
a widget every key of its layout entry except `id`, so a width is written
`{ "id": "omarchy.spacer", "size": 60 }`, not under a `settings` object. Nested,
it arrives as `settings.settings.size`, the widget reads nothing there and
falls back to its default, and the setting does nothing at *every* value. From
outside that is indistinguishable from a widget that does not work at all —
which is the wrong conclusion to reach, and an expensive one: the fix is to
check `entrySettings` in the bar's own `BarModel.js` before blaming the widget.

**A spacer is named by its place, not its id.** Its manifest sets
`allowMultiple`, so two spacers in a section are the same id twice and the bar
tells them apart by position alone. `bar move-at`, `shift-at` and the
`bar spacer` commands therefore take a section and an index, and carry the id
only to be checked against what is actually in that slot — a page acting on a
list read a moment ago must not resize whatever has moved into it since. The
by-id forms remain for the widgets that are unique.

**Disabling a widget is ours to do, not Omarchy's.** A widget is in
`.bar.layout` or it is not — that is the whole of its enabled state — and
`omarchy plugin disable` says so by removing the entry. It removes only the
entry, though, so the widget's own settings go with it: Omatop came back from a
round trip without its `showValues`, and Spotify would come back without its
account and its session. `plugin enable` then appends, so a widget switched off
and on again walks to the end of its section. So `bar_disable` keeps the whole
object, and where it was, in `.barHidden`, and `bar_enable` puts that object
back in its place. A widget this window never disabled has no place to go back
to, and that placement is Omarchy's to decide — so for that one case its own
command is what runs.

Each widget appears once on the page: under the section it sits in, or in
**Disabled** at the foot. A list of switches beside the three section lists
would have named every widget twice and left the reader deciding which list to
believe.

## The Plugins page

Add and remove hand off to the Omarchy flows in a terminal, because both ask
questions and print what they did. **Update does not.** `omarchy-plugin-update
<id> --yes` is entirely non-interactive — the diff and the confirm are the half
`--yes` skips — and a terminal opening over this window was the whole of what
that bought. So the row does the asking instead: how many commits are coming,
and what the first three of them say, read off the same `FETCH_HEAD` the count
came from, at no extra network cost.

**A plugin cannot update another plugin and stay on screen.** The shell watches
`~/.config/omarchy/plugins` with `inotifywait -m -r` and calls
`reloadPlugins()` on any change under it, which unloads every plugin widget —
including the bar widget hosting this window. A `git merge` is a change under
it, so the window goes. Deferring `omarchy-plugin-update`'s own
`rescanPlugins` does not help; the watcher has already fired. (This also
bites while testing: a `git` command run by hand inside any plugin directory
closes the window, so rewind a plugin *before* opening it, not after.) Three
things follow, and they are the design rather than a workaround:

- **The update is detached** (`setsid`, re-entering as `plugin update-run`).
  A child of the window would be killed part-way through its own merge.
- **It reports into the cache, not up its own stdout.** `running` says a
  spinner is owed, `last` says how it went. The page polls while something is
  in flight and picks up an update already running when it is built again, so
  the answer waits for the window to come back rather than dying with it. The
  page says up front that it will close, because it will.
- **It summons the window back.** The job that outlived the window is the only
  thing left that knows it should return, so it waits for
  `omarchy-shell shell ping` to answer, lets the teardown settle, and then
  calls `omacontrol showPage plugins` until the layer is actually there — the
  IPC call returns nothing either way, and a summon eaten by a dying panel
  looks exactly like one that worked. Whether to return is decided *before*
  the update, while the window is still up to be asked: afterwards there is no
  telling a window that was torn down from one the reader had closed, and
  opening a window nobody asked for is worse than not returning to one.

The update check fetches every plugin at
once and prints each verdict as it lands, so spinners retire one at a time
rather than all at the end; the verdicts outlive the sweep in
`~/.cache/omarchy/omacontrol/plugin-updates.json`, since a check costs a
network round trip per plugin.

The window is a plugin too, and says so in its own corner when it is behind:
the cached verdict draws it at once and a single background fetch corrects it
a moment after opening. The comparison is `omarchy-plugin-update`'s own — fetch
`origin HEAD`, count `HEAD..FETCH_HEAD` — on purpose, so the count never
promises an update the button then refuses to make.

