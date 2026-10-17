---
paths:
  - "bin/omacontrol-migrate"
---

# Migrating a rename

> **Read this when:** you touch `bin/omacontrol-migrate`. Open it deliberately
> if you are renaming any file this plugin writes into someone's config — that
> case has no glob to fire on.

## Migrating a rename

`bin/omacontrol-migrate` carries an OmaSettings install over. Worth knowing why
it is a script and not a line in the README:

**The require line breaks the desktop if it is missed.** `hyprland.lua` holds
`require("hypr.omasettings")`. Remove the file it names without rewriting the
line and Hyprland fails the config on the next reload — and Hyprland reloads on
its own whenever a file it loads changes. So the new file is put in place
first, the line is changed second, and the old file goes last, and only once
nothing still loads it: a reload landing anywhere in between loads the settings
once or twice, never not at all. If a hand-edited line survives, the old file
stays and the script says so.

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

**Three more, found the first time it was run for real rather than in a
sandbox:**

- **`omarchy plugin disable` removes the bar entry.** The script used to
  disable OmaSettings first and rename its id in `shell.json` second — and by
  then there was no entry left to rename, so the gear lost its slot and its
  keys. Renaming the id *is* the disable: Omarchy counts a plugin as enabled
  when its id appears in `shell.json`. The rename keeps the old slot and drops
  any OmaControl gear an `--enable` install already put in the bar.
- **Not every backup is in three directories.** Herdr, tmux and Neovim keep
  theirs beside their own configs, under `~/.config/<app>/`. Missed, they stayed
  `.omasettings.bak`, and OmaControl's first write took a fresh backup of the
  already-edited file — which a reset would then restore. The search walks
  `~/.config` now, and where both backups exist the older one wins.
- **The schema flags are not bookkeeping to carry.** `bindingsSchema` and
  `monitorsSchema` describe the data in the store they sit in; copied from
  OmaControl's store onto the old one, they would say a conversion had been
  done to data that never had it. They are ignored when deciding whether
  OmaControl has settings of its own, and never merged.
- **`XDG_CACHE_HOME` need not be under home.** The manifest recorded every path
  relative to home, so a cache outside it was restored by the undo into a
  directory that never held it. Paths outside home are recorded absolute.

The window offers the migration itself (`migrate_pending` in `lib/migrate.sh`,
an Overview notice) only while OmaSettings has state and OmaControl has none,
and runs it detached: the rename makes the shell reload every plugin, this
window with them, so the job reopens it afterwards the way a plugin update does.

Test it against a sandboxed `HOME` built from copies, never the live config,
and check the round trip with `diff -r --no-dereference`: migrate, undo, and
the tree should be byte-identical to where it started. Sandbox
`XDG_CACHE_HOME` as well as `HOME` — with only `HOME` redirected, a test run
moved the live cache.

