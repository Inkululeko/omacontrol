# OmaControl

An Omarchy shell plugin: one window for the settings that otherwise live
scattered across `~/.config/omarchy/shell.json`, the Hyprland config, the
per-application configs, and `~/.XCompose`.

It runs inside `omarchy-shell` — a single long-lived Quickshell (QML) process
that also draws the bar. There is no separate app: the plugin's service loads
the window on first use.

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
bin/omacontrol         Subcommand routing
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

## The five laws

These apply to every change. Everything else is in `.claude/rules/`, which
loads itself when you open a file it covers.

**1. Never parse and rewrite a hand-written config.** That is how a settings
app eats someone's setup. Every file we touch is one of three patterns:
generated wholly by us (`~/.config/hypr/omacontrol.lua`, or
`omacontrol.conf`), a marked block
inside their file (`bindings.lua`), or edited in place one value at a time
(`herdr/config.toml`, `tmux.conf`, `options.lua`). On top of that:
`backup_once` copies a hand-written file before the **first** write and never
again, and every format is validated in its own terms and rolled back on
failure. Full rules: `.claude/rules/other-peoples-files.md`.

**2. A QML change is not done until the shell has been restarted.** QML is
compiled into the long-lived Quickshell process and is not hot-reloaded, and a
page that fails to load leaves the window blank with no other sign — so a
`.qml` or `manifest.json` change that has not been through
`omarchy restart shell` has not been seen working and **must not be reported
as done**. Run `/verify`.

`lib/` and `bin/` are different and it is worth knowing which: the window
spawns `bash bin/omacontrol …` per call and `bin/omacontrol` re-sources every
module at the top of each invocation, so a shell change is live on the next
call. The exception is a watcher already running — `audio watch`,
`power watch` — which holds its code until its page is closed and reopened.

**3. Prefer Omarchy's own commands to reimplementing them.** They usually know
something you don't — `omarchy-bluetooth-power` clears an rfkill soft block
rather than setting BlueZ's `Powered`, because BlueZ forgets across reboots
and rfkill doesn't. Before building a page over something the bar already
shows, read the widget and use the same source, filter and labels.

**4. Theme first, always.** Never hardcode a colour in a page. Every surface
is an alpha over the theme's own foreground or accent, expressed in
`ui/Palette.qml`, so a Catppuccin desktop and a Gruvbox one each get the
design in their own colours.

**5. Comments say why, never what.** If a line explains the mechanics of the
code beside it, delete it. The ones worth writing record a decision, a
constraint, or a trap — an unbind before a bind so the override wins; the last
tmux assignment being the one that counts; reading the address from the Wi-Fi
device because the default route points at a VPN tunnel. User-facing strings
follow the same discipline in reverse: they say what a setting does for the
reader, never which command runs underneath.

## Where each page writes

This app stores almost nothing. Each page writes into whatever owns the
setting:

| Page | Lands in |
| --- | --- |
| Windows, Layout, Effects, Groups, Keyboard, Mouse & touchpad, Workspaces | `~/.config/hypr/omacontrol.lua`, loaded last (`omacontrol.conf` on a `.conf` setup) |
| Appearance | Omarchy's own config, via `omarchy-theme-set`, `omarchy font set`, `omarchy display text size` |
| Bar, Idle & Lock, Plugins | `~/.config/omarchy/shell.json` |
| Keybindings | a marked block in `~/.config/hypr/bindings.lua` |
| Compose Keys | `~/.XCompose` |
| Herdr, Tmux, Neovim | their own configs, edited in place |
| Displays | `~/.config/hypr/omacontrol.lua`, applied with `hyprctl eval` — plus `monitors.lua` for the laptop panel's scale |
| Audio, Network, Bluetooth, Power | nowhere — live system state, owned by PipeWire, NetworkManager, BlueZ and power-profiles-daemon |
| Overview | nowhere — every switch is Omarchy's own command, asked and relayed |
| Disk, Processes | nowhere — readings, plus the two or three things there are to *do* |

**Most of the store is not settings** — `hypr`/`hyprOriginal`, `written`,
`devices`, `monitors`, `bindings` and `extras` exist to say what changed and
put it back. The exceptions own themselves and nothing else holds them:
`windowRules`, `workspaceRules`, `barHidden`, `newsRead`, `newsSeeded`,
`dismissed`, `monitorsSchema`.

## The loop

`/verify` runs it: validate the manifest, `bash -n` over `lib/` and `bin/`,
qmllint against a recorded baseline, restart the shell, open the window, check
it **drew** rather than merely opened, and read the journal from before the
restart onwards.

QML errors surface **only** in the journal, and the ones that matter here do
not contain the word "error" — a binding loop, an undefined reaching a
QString, a page that failed to load, an ambiguous import reported as "File name
case mismatch".

`lib/` honours env overrides so writes can be aimed at a sandbox
(`OMACONTROL_STORE`, `OMACONTROL_HYPR_DIR`, `OMACONTROL_XCOMPOSE`,
`OMACONTROL_HERDR_CONFIG`, `OMACONTROL_TMUX_CONFIG`, `OMACONTROL_NVIM_OPTIONS`,
`OMACONTROL_BINDINGS_LUA`, `OMARCHY_SHELL_JSON`) — but **redirecting the file
does not redirect the system**: a sandboxed Hyprland write still reaches the
running compositor through `hyprctl eval`. To see what a write *produces*
without performing one, read `render_managed_lua`.

## Where the rest lives

`.claude/rules/` — path-scoped; each loads when you open a file it covers.

| Rule | Covers |
| --- | --- |
| `other-peoples-files.md` `shell.md` `changed-and-reset.md` `omarchy-commands.md` | `lib/`, `bin/` |
| `hyprland.md` `displays.md` `workspaces.md` | the compositor, monitors, window rules |
| `reporting-pages.md` `news.md` `bar-and-plugins.md` | the pages that report, the feed, the bar and plugin lifecycle |
| `qml.md` `navigation.md` `design.md` `search.md` | anything the reader sees or types at |
| `migration.md` | `bin/omacontrol-migrate` |

A path-scoped rule fires when Claude **reads** a matching file. If you are
editing through shell tools instead, open the rule yourself first.

`.claude/skills/` — `omacontrol-testing` (verify a change in the running
shell), `omacontrol-new-page` (add a page end to end), `omacontrol-setting`
(add a setting that writes into someone else's config).

`.claude/commands/` — `/verify`, `/lint`, `/page-shot`, `/state-diff`.

`.claude/agents/` — `omacontrol-reviewer` reviews a diff against these laws;
`devils-advocate` argues the other side of a plan or a piece of work.
