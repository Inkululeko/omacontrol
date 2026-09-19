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

