# OmaControl

An Omarchy shell plugin: one window for the settings that otherwise live
scattered across `~/.config/omarchy/shell.json`, the Hyprland config, the
per-application configs, and `~/.XCompose`.

It runs inside `omarchy-shell` — a single long-lived Quickshell (QML) process
that also draws the bar. There is no separate app: the plugin's service loads the
window on first use.

## Layout, and what each part may know

```
manifest.json          Plugin manifest — id, kinds, entry point
Panel.qml              The bar gear; forwards show/hide/toggle to the service
Service.qml            Owns the window (loaded on first use), the `omacontrol`
                       IPC target, and the launcher entry
SettingsWindow.qml     Window chrome, sidebar, page routing, and the state
                       every page reads. Pages reach it as `app`.
ui/                    Presentational components + the Palette singleton
                       NavRow is the base: one row the cursor can land on.
                       SettingRow and the table rows are layouts on top of it.
sections/              One file per page
bin/omacontrol        Subcommand routing
lib/                   One module per thing being configured
```

Three rules keep the split honest:

- A `ui/` component knows how a control looks and reports what happened
  through a **signal**. It never knows which setting it is editing, and never
  reaches back into the window.
- A `sections/` page knows what its settings mean and calls `app` to read and
  write them. It never shells out.
- `lib/` shells out. It never knows what any of it looks like.

When a page needs something new, the value goes into `lib/state.sh`'s single
JSON document and a getter goes on the window; the page reads `app.something`.

## The one rule about other people's files

**Never parse and rewrite a hand-written config.** That is how a settings app
eats someone's setup. Every file falls into one of three patterns:

1. **Generated wholly by us** — `~/.config/hypr/omacontrol.lua`, rendered
   from our store (`~/.config/omarchy/omacontrol.json`). Hyprland settings are
   applied live with `hyprctl eval` — not `keyword`, which does nothing on a Lua
   config — and recorded there; the generated file is loaded last so the user's
   own files still say what they wrote. It is created on the first write, not at
   install, and the `require` line is appended to `hyprland.lua` at the same
   moment.
2. **A marked block inside their file** — keybindings, appended to
   `bindings.lua` between `-- >>> omacontrol bindings` markers. Everything
   outside the markers is copied through untouched, and removing the last
   binding removes the block.
3. **Edited in place, one value at a time** — `herdr/config.toml`, `tmux.conf`,
   Neovim's `options.lua`. These are hand-written *and* commented, so a value is
   replaced exactly where it stands (keeping its comment attached) and a new one
   is appended to its table or file.

Two invariants on top:

- **First-touch backup.** `backup_once` copies any hand-written file to
  `<file>.omacontrol.bak` before the first write, and never again — later
  writes must not overwrite the pristine copy. Files we generate get no backup.
- **Validate, then roll back.** Each format is checked in its own terms:
  Herdr with `herdr config check`, Neovim by compiling the Lua, tmux by applying
  the option to the running server. On failure, restore the previous content and
  `die` with the tool's own message.

## The Workspaces page

An application bound to a workspace is a window rule: `o.window("slack",
{ workspace = "3" })`, the line people write at the foot of `hyprland.lua` by
hand. Ours go into the managed Lua under `.windowRules`, keyed by window class,
rendered in the same shape so the two read alike. A rule is an override, so a
row carries Remove rather than a reset; an off switch or an empty workspace
deletes the field rather than writing `false`, since `float = false` would pin
a window tiled against the user's own config.

**The class is the trap.** Slack's desktop entry says `StartupWMClass=Slack`
and its windows say `slack`, and a Hyprland match is a case-sensitive regex.
So `workspace_apps` lists desktop entries but takes the class from a running
window of the same name in any case when there is one, and lists running
classes with no entry at all. An application that has never run is bound by
its entry's class, which is the best guess there is.

Their own single-line `o.window("<class>", { ... })` rules are read, never
written, and shown as "set in your own config"; a value picked for the same
class lands in our file, which loads last and wins per property. A match given
as a table is about more than a class and is left alone. Removing a rule they
wrote comments the line out in place with a note, after `backup_once` and with
a `luac -p` check and restore — the same targeted edit a device block gets.

**The rest of a window rule is a short list, on purpose.** Beyond workspace
and how it shows, an application gets display, a floating size as a width and
height in percent of the screen plus a Centred switch (coordinates are for
Lua), pinned, no initial focus, idle
inhibit and no screen share. Opacity, blur, animation and the like are the
Effects page's, per application in Lua only, and groups and tags are left
alone. Pinned and placement only mean anything floating, so turning floating
off drops both rather than keeping a promise Hyprland ignores.

**Autostart is a desktop id, not a command.** "Start when you log in" writes
`o.launch_on_start("slack.desktop")` — Omarchy's own helper, launching through
uwsm by desktop entry id the way the launcher does — so the switch exists only
for an application with a desktop entry; a bare window class has no command
to start. Their own `o.launch_on_start("<id>.desktop")` lines are read, put
the application on the page, and are commented out on Remove with its window
rule. A bare command in their autostart is theirs to keep.

**Workspaces themselves are the second half of the page.** `.workspaceRules`
renders as `hl.workspace_rule({ workspace = "3", ... })`: display, default on
that display, persistent, default name, layout, and one "borderless" switch
that writes the five look rules together. Only a workspace with something set
gets a group; the rest wait behind a picker, so ten empty groups do not bury
the applications. Their single-line `hl.workspace_rule` calls are read and
commented out on remove, exactly as window rules are.

**A rule only governs windows that open after it.** So every write also
applies the rule in force to the windows of that class already open, through
`hyprctl eval` and the `hl.dsp.window.*` dispatchers with a `window =
"address:0x…"` target. Without this, "Shown as: Floating" left a fullscreen
Typora fullscreen — and Typora, like most Electron apps, remembers how it was
closed, so it came back fullscreen however the rule read. Two dispatcher traps:
`hyprctl dispatch <old syntax>` on a Lua config parses its argument as Lua and
fails — silently, if stderr is dropped — so nothing here uses it; and
`hl.dsp.window.float()` toggles whatever argument it is given, so it is sent
only to a window on the wrong side of the rule. `fullscreen_state` and `move`
do set rather than toggle.

## The three pages that are not settings

Overview, Disk and Processes report rather than configure, and that changes
where their data lives. **None of them is in the state document.** A state read
happens after every write anywhere in the window, and `df` on a machine with a
network mount — or two frames of `top` — would be paid for by every switch on
every other page. Each polls for itself instead, while it is the page on screen
and the window is open, exactly as Network and Bluetooth do.

`slicesSuffice` names all three, so a command of theirs re-reads *nothing*: the
page that asked for it polls, and it is the only thing that has to hear back.
Ending a process or trimming a drive changes nothing this window holds.

**Overview keeps no state of its own.** Every switch on it is Omarchy's —
`omarchy-toggle-nightlight`, `omarchy-shell notifications dndState`,
`omarchy-toggle-idle`, voxtype — asked on the poll and relayed on the flip,
side effects and all. That is what stops the page disagreeing with the bar,
which shows the same four things. Its "needs attention" list is two sources on
purpose: what only the shell can answer cheaply (how full `/boot` is) comes
from the reader, and what the window already holds (its own version, the
monitor list) is derived in the page rather than read a second time.

**A switch is only offered when it can work.** Installed is not the same as
usable: a voxtype with no model transcribes nothing, so the Dictation row asks
`voxtype status --extended --format json` — the same JSON the bar's indicator
reads — and reports itself unavailable when `model` is empty. Every switch on
the page drops out the same way rather than sitting there doing nothing. The
command is `voxtype record toggle`; there is no `voxtype toggle`, which is the
sort of thing that only shows up when someone tries the row.

**What is not on Overview, and why.** A package-update notice. Answering that
means `checkupdates`, which syncs a database over the network, and nothing in
this window may wait on the network. Omarchy's own update indicator already
says it.

**The Disk breakdown is not on the poll.** The only way to answer "what is
holding the space" is to walk directories, so it is its own subcommand, asked
once when the page opens. A walk that does not finish inside the read timeout
reports `null` rather than what it had got to — a partial `du` is not a small
number, it is a wrong one — and the page says so instead of quietly showing a
slice that is missing.

**Two samples, not one.** `/proc/stat` holds totals since boot, so a single
read gives the average since the machine came up: on a six-day uptime, a number
that never moves. Both the overall figure and the per-core bars are the delta
between two reads a fifth of a second apart. For the process list it is `top -b
-n 2` and the *second* frame, because `ps` reports a process's lifetime average
and would rank the browser that pinned a core an hour ago above the one doing
it now.

**A per-process CPU figure is a share of one core.** `top` calls a thread using
a whole core 100 %, which on sixteen cores is 6 % of the machine. The bars in
the table are scaled by the core count so they mean the same thing as the CPU
card above them.

## Migrating a rename

`bin/omacontrol-migrate` carries an OmaSettings install over. Worth knowing why
it is a script and not a line in the README:

**The require line breaks the desktop if it is missed.** `hyprland.lua` holds
`require("hypr.omasettings")`. Rename the file it names without rewriting the
line and Hyprland fails the config on the next reload. So the line is rewritten
*before* the file is moved — a reload landing mid-migration finds either the old
pair or the new one, never half of each.

**The store is the only copy of the originals.** `hyprOriginal` and `written`
are what "Undo all" puts back. Lose the store and the settings stay applied
with nothing to restore them to, which is worse than losing the settings.

**A `.bak` left under the old name is an original that stops being restored.**
`backup_once` only writes a backup when there is not one already. Under the old
name the new window sees none, takes a *fresh* copy of the already-modified
file, and that becomes what a reset restores.

**Three bugs this found, all of which the sandbox caught and review did not:**

- `grep -qF '-- marker'` reads the marker as an option. Every marker in this
  codebase is a Lua comment, so the guard reported "not present" and the
  renames that mattered most were silently skipped. `grep -qF -e "$x" --` is
  the form to use anywhere a pattern can begin with a dash.
- A rollback copy taken twice is a rollback copy of your own output. Two
  substitutions run over `bindings.lua`; the second `keep` copied the
  half-edited file, and the undo replayed the manifest in order so the dirtier
  copy won. Kept once, the way `backup_once` keeps once, for the same reason.
- Restoring originals is half an undo. The new-named files have to be removed
  too — and removed *before* the restore, since an original and the copy made
  from it are one path under two names.

Test it against a sandboxed `HOME` built from copies, never the live config,
and check the round trip with `diff -r`: migrate, undo, and the tree should be
byte-identical to where it started.

## Pages for applications you may not have

Tmux, Neovim and Herdr get a page each, and an application you do not have is
a page of settings with nowhere to go — so `pageAvailable()` drops it from the
menu, from the search counts and from Alt navigation, and steps off it if the
application goes away while its page is open.

**The binary is the test, not the config file.** An application can be
installed and never yet configured, and a config file can outlive the thing it
configured; only `command -v` answers the question actually being asked. Each
of the three reports it in its own state as `installed`.

## Where each page writes

This app stores almost nothing. Each page writes into whatever owns the
setting:

| Page | Lands in |
| --- | --- |
| Windows, Layout, Effects, Groups, Keyboard, Mouse, Workspaces | `~/.config/hypr/omacontrol.lua`, loaded last |
| Appearance | Omarchy's own config, via `omarchy-theme-set`, `omarchy font set`, `omarchy display text size` |
| Bar, Idle & Lock, Plugins | `~/.config/omarchy/shell.json` |
| Keybindings | a marked block in `~/.config/hypr/bindings.lua` |
| Compose Keys | `~/.XCompose` |
| Herdr, Tmux, Neovim | their own configs, edited in place |
| Displays | `~/.config/hypr/omacontrol.lua`, applied with `hyprctl eval` — plus `monitors.lua` for the laptop panel's scale |
| Audio, Network, Bluetooth, Power | nowhere — live system state, owned by PipeWire, NetworkManager, BlueZ and power-profiles-daemon |
| Overview | nowhere — every switch is Omarchy's own command, asked and relayed |
| Disk, Processes | nowhere — readings, plus the two or three things there are to *do* |

A display is the one thing here worth writing down as well as applying: it is
unplugged and plugged back in, and Hyprland matches its monitor rules again on
every connect. So a resolution or a scale set on the Displays page becomes an
`hl.monitor` call in the managed file, and a display that is **not** connected
can be set up by name for the next time it arrives. `hyprctl keyword monitor`
was the original bug there — it answers "keyword can't work with non-legacy
parsers" on stderr while exiting 0, so both settings looked applied and never
were.

**A connector is not a display.** `DP-2` is whichever screen is in that socket:
the monitor at work and the one at home are both `DP-2`, so settings keyed by
connector followed the cable instead of the screen. A display is therefore
keyed by what it says about itself — `desc:Dell Inc. DELL U2724D 1A2B3C4`,
which Hyprland matches as a monitor rule the same way the hand-written
`monitor = desc:...` lines of a `.conf` setup always did. That key is what the
store is keyed by, what `output` says in the managed Lua, and what a setting
key (`monitor:<key>:scale`) names; a connector name is the fallback, for a
display that reports no description, and is still accepted as input. Entries
written against connectors are re-keyed once, to whatever is in that connector
now (`monitorsSchema` 3).

The one exception is `monitors.lua`, below: the clamshell watcher looks the
laptop panel up by the connector name `omarchy-hyprland-monitor-laptop` prints,
so a `desc:` rule there is a rule it cannot see.

**The laptop panel's scale is not ours to keep.** Omarchy watches the internal
display: while a laptop is docked, `omarchy-hyprland-monitor-clamshell` runs
every couple of seconds, reads the scale out of `monitors.lua`, and puts the
panel back to it. A scale set from this page survived about a second, silently.
So for the internal panel — and only for its scale — the number is written into
`monitors.lua` as well, in place, the way every other hand-written config here
is edited: the rule for the panel gets its `scale` replaced, or a marked rule is
appended if there is none. Then the watcher enforces what this page chose. Every
line added carries the `-- omacontrol` marker, comments included, so removing
the setting takes the whole block. An external display needs none of this.

**Our store holds no settings of its own**, only what is needed to say what
changed and put it back: `hypr` and `hyprOriginal` (Hyprland keys we override
and what they were), `written` (pre-change values for settings living in other
people's configs), `devices`, `monitors`, `bindings`, and `extras` (animation
speed, full opacity). Delete the store and nothing you configured is lost —
only the memory of which parts came from here.

## Prefer Omarchy's commands to reimplementing them

Where Omarchy ships a command, drive it. It usually knows something you don't:

- `omarchy-bluetooth-power` clears an **rfkill soft block** rather than setting
  BlueZ's `Powered`, because BlueZ forgets across reboots and rfkill doesn't.
- `omarchy-bluetooth-device` trusts a device before connecting it.
- `omarchy-network-band` pins the band the same way the bar widget does.
- `omarchy-default-agent` / `-browser` / `-editor` install what is missing.

The Omarchy **menu definition** (`omarchy-menu.jsonc`, defaults merged with
`~/.config/omarchy/extensions/`) is the source of truth for pick-one groups —
agents, browsers, DNS providers. `menu_group_state` reads a group, and
`menu_run <entry-id>` runs an entry's action exactly as the menu would. Never
keep a second copy of those lists; they drift.

## When the bar already shows the same thing

A page that duplicates a bar widget has to agree with it, or the two become
two answers to one question. Audio was a lesson in this: `pactl` lists every
sink in the graph, so the page offered four HDMI outputs with no cable in them
and a physical speaker sink sitting behind a tuning, under names like "Radeon
High Definition Audio Controller HDMI / DisplayPort 3 Output". The widget shows
two devices called "ALC285 Analog" and "HDMI 3".

The difference was not taste. `omarchy-audio-sink-availability` reports which
sinks have a live port and hides the one a speaker tuning fronts; the widget
labels a device by its own short nickname (`node.nick`) rather than the
sentence PulseAudio assembles. Both now feed this page too.

Before building a page over something the bar already shows, read the widget
and use the same source, the same filter, and the same labels.

## Keyboard navigation

`PanelKeyCatcher` in `qs.Ui` defines the vocabulary Omarchy panels answer to,
and this window follows it rather than inventing one: Up/Down and j/k move,
Left/Right and h/l change a value, Enter and Space act, Tab changes section,
Escape closes. Alt+Up/Down for the sidebar, Home/End, and Backspace for the
(reset) beside a changed setting are the additions a window with pages needs.

The cursor lives in `SettingsWindow`, but a row says what it means: `SettingRow`
carries `current`, `navActivate()` and `navStep(delta)`, and each row type
answers those in its own terms — a switch flips, a slider steps, a picker
opens. A row type that answers neither is still navigable and simply does
nothing when activated.

Rows register themselves on load, by walking up to the page and taking the
`app` handle it was loaded with — a window is not the visual parent of what it
shows, so walking to the top does not find it. The order is recomputed from
where rows actually sit, not from the order they registered, since groups come
and go with the settings they depend on.

Two things worth knowing before changing this:

- **A field commits by losing focus, and stops its own Enter.** `accepted`
  fires without accepting the event, so an Enter left to bubble reaches the
  window, which reads it as "activate this row" and drops straight back into
  the field it just left. Editing is a flag the row owns rather than a reading
  of `activeFocus`, which the field can take back on its own.
- **A row holding the keyboard sets `navBlocking`** — an open dropdown, a field
  being typed into. The window then forwards every key, Escape included, or
  Escape would close the window out from under an open list.
- **Stepping keeps its own `pending` value.** A write takes a state refresh to
  come back, and two presses inside that window would both compute from the
  same stale number, so the second would be swallowed. `effective` is what the
  slider and the next press read.

## Changed, and putting back

"Changed" means the value differs from what the setting was before this window
first wrote it — not merely that the window wrote it. A switch flipped and
flipped back is not a change, and must stop saying it is.

Three kinds of change, three ways back:

- **A Hyprland key** is an override: drop it and the value comes from wherever
  it came from before — Omarchy, the theme, a hand-written `looknfeel.lua`.
  A **per-device** setting is the same shape; clearing it hands the device back
  to the global one, so the store is the whole record and no original is kept.
- **A value in someone else's config** — theme, font, text size, the bar, the
  idle timeouts, tmux, Neovim, Herdr, a monitor scale — has no unset state.
  The way back is the value found before the first write, kept in `.written`
  under a key naming what it configures (`tmux:mouse`, `device:<name>:<opt>`,
  `monitor:DP-2`). Hyprland keys keep theirs in `.hyprOriginal`.
- **A list you add to** — compose entries, keybindings — is not a setting with
  a default at all. Those rows carry Remove, Turn off and Restore, which is
  what a thing you created wants rather than a reset.

The window shows one mark for all of them, because from the outside they are
the same thing: you changed it, and it can go back. `Ctrl+Backspace` or the **Reset all
settings** button under the menu puts back everything at once, after asking — the one
action here a second click cannot undo.

The live pages are deliberately unmarked: audio, network, bluetooth and power
move on their own, so "you changed this" would be a guess.

Three things this will not forgive:

- **Read the previous value before the write.** Read after, and the recorded
  original is the value it has just become.
- **Read it with `has()`, never `//`.** jq's alternative operator treats
  **false** as empty, so every switch that starts off reads its original back
  as null and never matches. This bit twice: Shadow, Blur and Glow went on
  claiming a change after being turned off again.
- **Restoring writes the value found at the first change.** If a theme has
  moved text size since, the reset puts back the older number, not the theme's.
  A key written before any of this existed has no original at all, and stays
  marked until reset once.

## The two that are not keywords

Speed and full opacity cannot be set or read like the rest, because Hyprland
has neither. Each is a piece of Lua written into the managed file, with a
value of our own in `.extras` saying what to write, and both ride into the
window inside `state.hypr` so a page asks for them like anything else.

- **Speed** multiplies the animation set Omarchy ships, read from
  `default/hypr/looknfeel.lua` rather than from the running config: reading
  live speeds would multiply what has already been multiplied and the setting
  would run away from itself. The cost is that an animation you wrote yourself
  is replaced by the scaled default while this is anything but 1.
- **Full opacity** writes `o.window(".*", { opacity = "1.0 1.0" })`. Omarchy
  tags every window and fades it to 0.985, which multiplies with the opacity
  sliders, so without this 100% renders at 98.5%. The managed file loads last,
  so the rule lands after the one it is undoing.

## Keyboard values that will not compile

Hyprland accepts a layout or variant xkb cannot build and says nothing: it
keeps the last keymap that worked, so the window would show the new value
while the keys went on doing the old thing — or, worse, leave you unable to
type the fix. `kb_check` compiles the pair as it would be after the write
(either half can break it) with `xkbcli compile-keymap`, and refuses before
anything is written. It runs for the per-device settings too.

Options are deliberately not checked: xkb ignores an option it does not know
rather than failing, so a typo there costs nothing, and a check would only be
a guess at a list that changes.

## The legend bar

Fourteen keys listed at once would be a wall nobody reads, so the bar says
what the keys do *here*: the four that always apply, plus whatever the cursor
is on. A row type declares its own keys in `navKeys` — the same place it
answers `navActivate` and `navStep` — so a new row type that forgets adds
nothing to the bar rather than lying about what it does.

`\u232b Reset` appears only on a row this window has changed, which makes the
bar the discovery path for the reset as well.

## Which screen it opens on

A layer surface goes to the screen it is given, and given none it goes to the
first one — so on two monitors the settings could open on the one you are not
looking at. Hyprland knows which monitor has the focus and Quickshell knows
the screens by name; `focusedScreen()` matches the two, and `show()` pins the
result for that opening.

Pinned, not bound: a window that hops to another screen because the focus
moved is worse than one that stays where it was opened. This machine has one
monitor, so the choice is verified by what it resolves rather than by where
it lands.

## Rows that are not settings

A device, a network and a binding are lists of things rather than one setting
each, and their rows are built to look like it — `PickableRow`, `DeviceRow`,
`WifiRow`, `BindingRow` are not `SettingRow`s. `NavCursor` carries the cursor
contract into them instead of forcing them into that shape: drop one in,
anchored over the row, and the row joins the cursor. It registers itself, not
its parent, and mirrors the geometry the window sorts by, so from the window's
side it is another row.

Its key is whatever clicking the row does, which is not fixed: connect or
disconnect depending on the device, remove or turn off depending on whose
binding it is. The legend says which, because the row does.

## Search

Only the open page is instantiated, which is what keeps the window cheap and
what makes searching awkward: the window cannot ask a page it has not built
what it holds. `omacontrol search` reads the section sources instead and
returns every label, description and heading per page, keyed by the page ids
taken from `SettingsWindow.qml`'s own routing — so a page renamed or a setting
added is in the index without a second list to update.

The index arrives with the state, not from a call of its own, because half of
it is the state: a page that is a list of things — this keyboard, that
network, your bindings, the plugins you have — can only be described by the
running system, and `state.sh` has already asked. The section sources give the
rest. Rows named by the system say so through `NavCursor.searchText`.

One thing follows from that:

- **The index is only as fresh as the state.** A device that appears while the
  window is open is searchable at the next read, not the moment it arrives.
- **The heading is part of the match, in both places.** The index carries the
  group, and rows read their heading off the `SettingGroup` above them, or a
  search for "blur" would count eleven settings and show seven.
- **So is the page name, and its parent's.** "bluetooth" has to find a page
  whose rows are all device names, and "applications" has to find what sits
  under it. A page whose name matches is listed whatever its settings are
  called — including the pages that declare no labels at all, which is why
  those show no number beside them.
- **Every page needs its own `case` in `sectionSource`.** The index learns
  which file holds which page by reading those cases; a page reachable only
  through the `default` branch is one the search cannot see. That is exactly
  what hid Herdr's 25 settings.

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

## Watching instead of asking

Two pages follow the system rather than re-reading it. Audio follows
`pactl subscribe`, because mute and volume belong to the server and the media
keys, the bar and every other panel move them. Power follows three signals at
once — the profile daemon over D-Bus, UPower for the battery, and inotify on
the files `omarchy-powerprofiles-set` writes — because the bar's power plugin,
the menu and the daemon all move the profile.

Both run only while their page is open, and both drain a burst of events
before re-reading, or one key press costs four reads. The monitors are killed
by an EXIT trap *and* by a watchdog on the reader, since neither notices the
page closing on its own.

Every other page is only as fresh as the last state read. Change a theme
elsewhere and this window shows the old one until something makes it read
again — worth knowing before chasing a "stale value" bug that is not one.

## Reading Hyprland in one call

`hypr_state` asks for every setting in a single `hyprctl --batch` and sorts the
answers out in jq. One call each was fine at a dozen settings and not at
seventy-odd: it took a second on its own, the window sat on "Loading" for
seconds, and — the part that actually misleads — every page rendered the
fallbacks written into its rows rather than the values Hyprland holds. If a
page shows suspiciously round numbers, suspect that before suspecting the page.

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

## Testing

There is no hot reload worth trusting for structural changes. The loop is:

```bash
omarchy plugin validate .                 # manifest against the schema
omarchy restart shell                     # ~7s; the bar is dead meanwhile
sleep 8
omarchy-shell omacontrol show            # or hide / toggle
journalctl --user --since "-20 s" --no-pager | grep -i omacontrol
```

QML errors surface **only** in the journal — a page that fails to load leaves
the window blank with no other sign. Grep for `qml`, `not a type`,
`non-existent property` and `undefined`.

**Driving it from the keyboard.** `wtype` types into whatever holds keyboard
focus, and the window takes focus exclusively while it is open — so check it
is open before every burst:

```bash
hyprctl layers -j | jq -e '..|select(.namespace?=="omacontrol")' >/dev/null \
  && wtype "/" && wtype "blur"
```

Skip that check and the keystrokes go to the terminal you are working in. Two
things close the window out from under a test: `Escape` with nothing focused,
and `toggle` when it is already open. `Escape` only clears the search when the
search box has focus.

**Finding it in a screenshot.** `grim -g` takes *logical* coordinates while a
full `grim` capture is physical pixels, and the card is 90% of the screen
centred — three different frames of reference. Capture the whole screen, crop
from that with `magick`, and read the geometry out of
`hyprctl monitors` rather than assuming it.

To see a page without clicking, set `property string pageId` in
`SettingsWindow.qml`, restart, screenshot with `grim`, then set it back to
`"appearance"` before committing.

```bash
geom=$(hyprctl -j clients | jq -r '.[]|select(.title=="OmaControl")
  |"\(((.size[0])*1.6)|floor)x\(((.size[1])*1.6)|floor)+\(((.at[0])*1.6)|floor)+\(((.at[1])*1.6)|floor)"')
grim -o DP-2 shot.png && magick shot.png -crop "$geom" +repage page.png
```

(The ×1.6 is this monitor's scale: `hyprctl clients` reports logical pixels,
`grim` captures physical ones.)

The CLI is testable on its own, and `lib/` honours env overrides so writes can
be aimed at a sandbox: `OMACONTROL_STORE`, `OMACONTROL_HYPR_DIR`,
`OMACONTROL_XCOMPOSE`, `OMACONTROL_HERDR_CONFIG`, `OMACONTROL_TMUX_CONFIG`,
`OMACONTROL_NVIM_OPTIONS`, `OMACONTROL_BINDINGS_LUA`, `OMARCHY_SHELL_JSON`.

**Redirecting the file does not redirect the system.** `OMACONTROL_HYPR_DIR`
moves the *files*; it does not move Hyprland. A sandboxed Hyprland write still
goes to the running compositor through `hyprctl eval`, so a "safe" demo changes
the gaps on the screen in front of you. A sandboxed tmux write still applies to
the running server, and a sandboxed keybinding write still reloads Hyprland.

Check what else a write touches before running it, and if you only want to see
what a write *produces*, read `render_managed_lua` rather than performing one.

Before refactoring, capture `bin/omacontrol state | jq -S .` and diff against
it afterwards; volatile fields (`.datetime.now`, Wi-Fi signal) need deleting
first.

## QML traps that cost real time here

- **Don't import `QtQuick.Controls` alongside `qs.Ui`.** Both export `Button`
  and `TextField`; the ambiguity fails the whole file, and the shell reports it
  as the useless "File name case mismatch".
- **The `Palette` singleton needs an explicit directory import.** Files in
  `ui/` use `import "." as Local` and `Local.Palette.foreground`; the implicit
  directory import does not resolve it here.
- **Pages get `app` through `Loader.setSource(url, { app: root })`**, not a
  plain `source` assignment — otherwise every binding evaluates against a null
  window on load.
- **`summon` on a bar-widget+panel plugin routes to the widget**, not the panel.
  That is why the window is not a `panel` entry point: it lives in the service,
  and the bar widget stands in for it with `open`/`close`/`opened`.
- **Icon glyphs are not guaranteed.** Signal-strength codepoints render as tofu
  in this Nerd Font, so signal bars are drawn with rectangles. Omarchy's own
  icon font is resolved by *file* (`fc-list ':family=omarchy:charset=e905'`) and
  loaded with a `FontLoader`, because more than one file can claim the family.
- **`forceActiveFocus()` on a `FocusScope` gives focus back to the child that
  had it last** — which, when a field has just finished editing, is that field.
  The scope holds a `keySink` Item for focus to land on instead.
- **A `TextField` emits `accepted` without accepting the event.** An Enter left
  to bubble reaches the window, which reads it as "activate this row" and drops
  straight back into the field just left. Handle Enter at the field and accept
  it there.
- **A `Repeater` is a visible child with no height**, sitting among the rows it
  made. Counting children to decide whether a group is empty must skip it, or
  every heading survives a search that removed everything under it.
- **A binding read from inside its own change handler is the previous value.**
  `onSearchTermChanged` reading `sidebarRows` got the list for the term before,
  and switched to a page that no longer matched. Recompute from the source, not
  from the binding you are invalidating.
- **A property named `<x>Changed` collides with `<x>`'s change signal.**
  `hyprChanged` beside `hypr` is a duplicated name; Qt 6's qmllint catches it,
  Qt 5's does not.
- **A child anchored to a parent that sizes itself from its children is a
  binding loop.** Row content anchored to `verticalCenter` of a holder whose
  `implicitHeight` is `childrenRect.height` loops silently — it shows up in the
  journal, not in the lint.
- **`hyprctl keyword` does nothing on a Lua config.** It answers "keyword can't
  work with non-legacy parsers. Use eval." — on stderr, while still exiting 0,
  so a setting looks applied and is not. `hypr_apply_live` sends
  `hyprctl eval 'hl.config({...})'` instead, with the keyword form kept for
  setups still on `.conf`. Per-device settings go the same way, as
  `hl.device({ name = ..., ... })`.
- `qmllint` on `PATH` is Qt 5's (`qt5-declarative`), and Quickshell is Qt 6.
  It cannot parse a typed function signature — `function show(): void`, which
  `IpcHandler` requires — and exits 255 with no output when it meets one, so
  `Panel.qml` never gets linted by it. It also passes nearly everything else
  regardless of merit, which makes a clean run from it worth nothing. Use the
  Qt 6 binary, and give it the `qs.*` root, which Quickshell aliases to the
  shell directory:

  ```bash
  mkdir -p /tmp/qsimports && ln -sfn /usr/share/omarchy/shell /tmp/qsimports/qs
  /usr/lib/qt6/bin/qmllint -I /tmp/qsimports SettingsWindow.qml sections/*.qml
  ```

  Two warnings are expected and are not yours to fix: `Property "state"
  already exists in base type` (the window has carried it from the start) and
  `Type PanelWindow is not creatable`, which Omarchy's own bar and menu raise
  on the same type. Unqualified-access and missing-property notes on `Style`
  and `Color` are singletons qmllint cannot follow.

  Even so, the authoritative check is the shell loading the file.

## Per-device input

Hyprland lets one keyboard or pointer depart from the global input settings
(`hl.device`). Each device gets **its own group**, below the global settings
and titled with the device name, so what a control writes is never in doubt:
the rows under a device name write that device, the rows above write all of
them.

The first attempt used one picker that switched what the page's controls wrote.
It was fewer rows and it was wrong — the same slider meaning different things
depending on a dropdown three groups up is a trap, not a saving. If a control
can write to two places, show two controls.

Only a device that has departed from the global settings gets a group. The
rest sit behind one "Settings for one pointer" dropdown, so a machine with five
input devices and no overrides still reads as a page about pointers rather than
a list of hardware.

A device row shows the value in force for it: what was set here, else what the
user's own config gives it, else the global setting above.

Removing a device takes its `hl.device` with it, including one the user wrote:
that block is **commented out rather than deleted**, with a line saying how to
bring it back, and the file is checked with `luac -p` and restored if the edit
broke it. Their config is still never regenerated — this is the same targeted
in-place edit the per-application configs get.

`hyprctl devices` also reports **displays** as input devices: a monitor's HID
control endpoint advertises keyboard and pointer capability, so DP-3 arrives as
a keyboard `dp-3` and a mouse `dp-3-1`. They are filtered by DRM connector
shape (`dp-1`, `hdmi-a-2`, `edp-1`, and their numbered siblings) rather than
against the connected monitors, because an unplugged display leaves its input
device behind.

`hyprctl devices` reports far more devices than anyone has on a desk — power
buttons, lid switches, video buses, virtual keyboards — so `devices.sh` filters
them out. The picker hides itself entirely when only one real device exists.

Two things the first version got wrong, both worth keeping in mind:

- **A device you own is not always plugged in.** Listing only what
  `hyprctl devices` reports means a Bluetooth mouse vanishes from settings the
  moment you undock. Devices that appear in any config are listed too, marked
  "(not connected)".
- **Read their config even though you never write it.** The no-parsing rule is
  about *writing*. A device already configured in `input.lua` would otherwise
  read as unconfigured here, and a value set from this page would silently
  fight a line the user wrote by hand. `device_config_settings` reads the
  `hl.device` blocks out of their Lua, and a control falls back
  ours → theirs → global, which is the order Hyprland itself resolves them in.

## Design

The window is a settings app, so it follows what settings apps have settled on.

**Theme first, always.** The design this window is drawn from has a warm
palette of its own. What is taken from it is the *hierarchy* — which surface
sits on which, how far apart two greys are, what is a pill and what is a card —
and every one of those is expressed in `ui/Palette.qml` as an alpha over the
theme's own foreground or accent. So a Catppuccin desktop and a Gruvbox one
each get the design in their own colours. Never hardcode a colour in a page.

**Three surfaces and no more:** the window, the rail beside it, and the cards
on it. Anything finer stops being visible once a theme supplies the colours.

**The rail is flat and clustered.** Every page is its own row; the only thing
between one cluster and the next is whitespace. Nothing folds open. A tree
earns its keep when a branch holds more than a screenful, and these hold four
rows each — the fold was one click between the reader and a page they could
otherwise have hit directly. The gap above a cluster is part of the *row's*
height rather than list spacing, so it survives a search that empties the rows
either side of it.

**A tinted square in front of every row.** Eight tints, one per cluster, is
what lets someone find "the network one" without reading the list — and it
carries the grouping even after a search has pulled the clusters apart. One
accent cannot make eight distinguishable colours, so the clusters are spread
along the distance between the accent and the foreground.

**The page says where it is, not just what it is.** A flat rail of twenty-six
rows tells the reader where they can *go* and nothing about where they *are*,
so every page carries a `crumb` and the header prints it over the page name.
It is not always the cluster: Displays is filed under Desktop, but a reader
arriving there is thinking about screens.

**What has changed sits beside what it undoes.** The count and "Undo all" are
in the page header. In the rail they sat under a menu they had nothing to do
with and read as an action on the menu.

**A card, not an indent.** `SettingGroup` used to step its rows in from its
heading. A card says the same thing better: an indent has to be compared
against the heading above it to be read at all, while an edge is visible on its
own — and it holds where the rows are a table or a list rather than settings.
A row's cursor band runs to the card's inside edges, since overshooting a card
is visible in a way that overshooting a bare page never was.

**One table, used three times.** `DataTable` draws the mounts, the processes
and the snapshots. A table and not a list of rows because the reader is
comparing down a column — which partition is fullest, what is eating the CPU —
and that only works if the figures line up. Actions go *under* the table and
act on the selected row: five rows each carrying four buttons is twenty
buttons, nineteen of which are about a row nobody is looking at.

**The Overview toggles are tiles, and a filled tile is on.** Four across, each
with a round icon badge and its switch on one line and the name and state
under them. Not rows: the question these answer is *which of these are on right
now*, asked of all four at once and often from across the desk, and a column of
rows answers it with four small knobs in a vertical line that have to be read
one at a time. The fill is the state; the switch is only the affordance, which
is also why the whole tile takes the click.

A grid of tiles goes in an *unframed* `SettingGroup` (`framed: false`) — the
tiles are the cards, and a card around them is a border drawn twice and a
padding paid for twice.

**A wash over an accent fill is struck from `onAccent`, never from white.**
`Palette.onAccentWash(alpha)` exists because the badge and the switch track on
a filled tile were `Qt.rgba(1, 1, 1, 0.22)`, which is invisible on a light
accent. Nothing errors; the control just loses half of itself under half the
themes, which is the failure mode this whole palette is meant to prevent. The
same applies to the sidebar's selected icon square.

**Keycaps, at last.** The legend along the foot is drawn as keys. It was plain
text on the grounds that a row of boxes pulls the eye off the settings, and
that holds only if the caps are large or loud — small, low-contrast and all one
size, the bar reads as one band of chrome. It still *follows the cursor* rather
than listing everything, which the mockup did not: the keys that always apply,
plus whatever the row under the cursor answers to.

**Name a thing once.** A page called Bluetooth should not then contain a group
called Bluetooth containing a row called Bluetooth. If a heading and the thing
under it would carry the same word, the heading goes.

**A control that governs the whole page belongs in the header.** Pages can
declare `property Component headerControl` and `property string headerNote`;
the window renders the control beside the page name and the note under it. The
header once named the file a page writes to, which was a promise the pages
could not keep — Displays lands in two files on a laptop, Appearance in
whatever Omarchy's commands touch — and it said nothing about the setting the
reader was looking at. The Bluetooth adapter switch and its state live there.
Anything that governs only part of a page stays a row.

**Lead with what the page is for.** Network opens with the Wi-Fi switch and
the networks it finds, because choosing a network is why anyone comes here.
Address, gateway and band are about the network you already picked, so they sit
under Connection *after* the list rather than between the switch and it.

**Group by the question being asked, not by the data.** Bluetooth devices are
Connected, Paired and Nearby — three headings — because those answer *what am I
using*, *what do I own*, *what else is here*. One list sorted by state makes the
reader infer the boundaries from the buttons on each row.

**What belongs to a heading is stepped in from it.** `SettingGroup` indents
its note and its rows under a title, so membership is a matter of looking
rather than of reading. A group with no title indents nothing — there is
nothing to belong to.

**A handful of short choices go side by side, not in a dropdown.** `ChoiceRow`
wraps the kit's `ButtonGroup` — the same pills the bar's network widget uses —
so DNS providers are all visible at once. A dropdown is for lists that are long
(themes, fonts) or whose labels are sentences; opening one to discover there
were only four options is a wasted click.

**A row that sets its own `visible` must keep the search in it.** `NavRow`
binds `visible: !searchHidden`, and a page that writes `visible: <condition>`
replaces that binding outright — the row then stays on screen through every
search, which reads as the filter being broken rather than as one row opting
out. The form is always `visible: !searchHidden && <condition>`; a group uses
`!searchEmpty` the same way. It is invisible in review and obvious the moment
you type in the search box, which is how fourteen of them shipped at once.

**A heading earns its place or disappears.** `SettingGroup` renders no heading
when its title is empty, which is right for a page with a single group; the
page name is already the heading.

**Say what a setting does, never what it runs.** Notes and descriptions are for
the reader — "Off lets the terminal handle clicks, so links stay clickable",
not "runs omarchy-bar transparent toggle". Implementation belongs in code
comments and the README.

**A note that restates its own rows is noise.** "Paired — yours, but not
connected right now" tells the reader nothing the heading and the rows did not.
A note earns its place by adding a fact you cannot see: that an uninstalled app
gets set up when you pick it, that a bar widget still needs a slot in the bar.

**Don't repeat state that is visible below.** The header says whether Bluetooth
is on, not which devices are connected, and the Wi-Fi switch does not name the
network you are on — the list under both is already saying it, a few rows down.

**A page that watches something keeps itself current.** Network and Bluetooth
poll every five seconds while they are the page on screen *and* the window is
open (`running: app.shown`), through a light `poll` subcommand that returns
what is known right now rather than re-reading the whole state. Nobody should
have to press a button to see what is in the room.

Discovery differs between the two: a Wi-Fi scan is a one-shot request that
NetworkManager rate-limits, while Bluetooth discovery is a *mode* the adapter
has to be held in. So the Bluetooth poll keeps a 30-second `bluetoothctl scan`
alive and lets it lapse once the polling stops — the page never has to clean up
after itself.

## Shell conventions

Bash with `set -uo pipefail` (not `-e`; several reads exit non-zero normally).
`jq` for all JSON.

**`... | jq ... || echo '[]'` is a bug under `pipefail`.** The status of
`producer | jq` is the *producer's* failure, even when jq went on to make
perfectly good JSON out of the nothing it was given — so the fallback fires
*as well*, and jq's answer with `[]` stapled to it is not JSON at all. It fails
only when run through `bin/omacontrol`, which is the one place `pipefail` is
set, so it passes every test run by hand. Use `emit_json "$(...)" '[]'` from
`core.sh`: the value decides, not the exit status.

Two `jq` habits worth remembering:

- Inside `($list | index(.x))` the `.` is now `$list` — bind the value first
  (`. as $row | ... index($row[1])`) or every row matches.
- Building a whole file as one string in `awk` (`out = out c`) is quadratic;
  scan per line. That cost 3 seconds of a 3.4-second window open once.

## Comments

Comments say **why**, never what. If a line explains the mechanics of the code
beside it, delete it. The ones worth writing are the ones that record a
decision, a constraint, or a trap — an unbind before a bind so the override
wins; the last tmux assignment being the one that counts; reading the address
from the Wi-Fi device because the default route points at a VPN tunnel.

User-facing strings follow the same discipline in reverse: they say what a
setting does for the reader, never which command runs underneath.
