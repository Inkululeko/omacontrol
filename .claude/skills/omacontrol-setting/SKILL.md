---
name: omacontrol-setting
description: Add or change a setting in OmaControl that writes into a file OmaControl does not own — a Hyprland option, shell.json, tmux.conf, options.lua, config.toml, .XCompose, or a per-device or per-monitor rule. Use whenever a new control has to persist somewhere. Covers the write path, the first-touch backup, validate-and-roll-back, recording the original so the setting can be put back, and the row that shows it changed.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# Adding a setting

Work outwards from the file it lands in. The order matters: most of the ways
this goes wrong are ways of recording the wrong "before".

## 1. Decide which file owns it, and which of the three patterns applies

- **Generated wholly by us** — `~/.config/hypr/omacontrol.lua`, rendered from
  our store. Nothing to preserve; re-render it.
- **A marked block inside their file** — between `-- >>> omacontrol` markers.
  Everything outside the markers is copied through untouched, and removing the
  last entry removes the block.
- **Edited in place, one value at a time** — hand-written *and* commented, so
  the value is replaced exactly where it stands, keeping its comment attached,
  and a new one is appended to its table or file.

**Never parse and rewrite a hand-written config.** Read
`.claude/rules/other-peoples-files.md` before writing the setter.

## 2. Write the setter

```
read the previous value          # before the write, or the "original" you
                                 # record is the value it has just become
backup_once <file>               # hand-written files only; never ours
write
validate in the format's own terms
  herdr config check | luac -p | tmux set on the running server
on failure: restore, and `die` with the tool's own message
```

## 3. Record what it was, so it can be put back

| Kind of setting | Where the way back lives |
| --- | --- |
| A Hyprland key | `.hyprOriginal` — or nothing: dropping the override restores whatever it came from |
| A per-device setting | nothing; clearing it hands the device back to the global one |
| A value in someone else's config | `.written`, keyed by what it configures (`tmux:mouse`, `device:<name>:<opt>`, `monitor:<key>:scale`) |
| A list you add to | nothing — compose entries and keybindings carry Remove, Turn off and Restore instead of a reset |

Two ways this fails, both of which have shipped here before:

- **Read the previous value before the write.** Read after, and the recorded
  original is the value it has just become.
- **Read it with `has()`, never `//`.** jq's alternative operator treats
  **false** as empty, so every switch that starts off reads its original back
  as `null` and never matches. Shadow, Blur and Glow each went on claiming a
  change after being turned off again.

"Changed" means the value differs from what it was before this window first
wrote it — not merely that the window wrote it. A switch flipped and flipped
back is not a change and must stop saying it is.

## 4. Route it

`lib/setters.sh` for the `set` subcommand, `setting_reset` for the way back.
If the setting is a Hyprland option it is applied live with `hyprctl eval`
— **never `hyprctl keyword`**, which answers "keyword can't work with
non-legacy parsers" on stderr while exiting 0, so the setting looks applied
and is not.

## 5. Put it in the state document and on the page

A getter on `SettingsWindow.qml`, then the row. The row form is always:

```qml
visible: !searchHidden && <your condition>
```

A row that writes a bare `visible: <condition>` replaces `NavRow`'s
`visible: !searchHidden` binding outright and then stays on screen through
every search — which reads as the filter being broken rather than as one row
opting out. A group uses `!searchEmpty` the same way. This is invisible in
review and obvious the moment you type in the search box, which is how
fourteen of them shipped at once.

## 6. Verify

A setter is `lib/` only, so it is live on the next call — exercise the setting
and its reset in the window without restarting anything. If the change also
touched a `.qml`, run
`.claude/skills/omacontrol-testing/scripts/verify.sh` first. Before a refactor, capture
`bin/omacontrol state | jq -S .` and diff against it afterwards — `/state-diff`
does this, deleting the volatile fields first.

## Gotchas

- **Redirecting the file does not redirect the system.** `OMACONTROL_HYPR_DIR`
  moves the files; it does not move Hyprland. A sandboxed write still reaches
  the running compositor through `hyprctl eval`, a sandboxed tmux write still
  applies to the running server, and a sandboxed keybinding write still
  reloads Hyprland. To see what a write *produces*, read `render_managed_lua`
  rather than performing one.
- **A keyboard layout or variant xkb cannot build is accepted silently.**
  Hyprland keeps the last keymap that worked, so the window shows the new
  value while the keys go on doing the old thing — or you cannot type the fix.
  `kb_check` compiles the pair as it would be *after* the write, because
  either half can break it.
- **A `.bak` under an old name is an original that stops being restored.**
  `backup_once` only writes a backup when there is not one already.
- **`… | jq … || echo '[]'` is a bug under `pipefail`.** The status is the
  producer's, so the fallback fires *as well* and staples `[]` onto perfectly
  good JSON. Use `emit_json "$(...)" '[]'` — the value decides, not the exit
  status. It fails only through `bin/omacontrol`, the one place `pipefail` is
  set, so it passes every test run by hand.
