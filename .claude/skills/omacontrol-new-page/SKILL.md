---
name: omacontrol-new-page
description: Add a page to the OmaControl window, or rename/remove one. Use when the request is for a whole new screen in the settings window rather than one more setting on a page that exists. The work crosses five files and search breaks silently if one of them is missed.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# Adding a page

A page is not one file. It is five touch points, and the window will look
fine with four of them done — the page opens, the settings work, and search
cannot see any of it.

## The five

**1. `lib/<thing>.sh`** — the module that shells out. One file per thing being
configured. Add it to the `for module in …` list in `bin/omacontrol`, and give
it a `<thing>_cmd` router with a `case` in `main()`.

**2. Where its data lives.** Two answers, and picking the wrong one is the
expensive mistake:

- A page of **settings** puts its values in `lib/state.sh`'s single document
  (`par_run <name> state_<name>` inside the parallel block) and a getter on
  `SettingsWindow.qml`. The page reads `app.something`.
- A page that **reports** — readings, lists, anything that costs real time or
  touches the network — is **not in the state document**. It polls for itself
  while it is the page on screen and the window is open (`running: app.shown`),
  the way Network and Bluetooth do. A state read happens after every write
  anywhere in the window, so a `df` on a machine with a network mount would be
  paid for by every switch on every other page. See
  `.claude/rules/reporting-pages.md`.

  Add its command to `slicesSuffice` in `SettingsWindow.qml` so an action of
  its own re-reads nothing.

**3. `sections/<Thing>Section.qml`** — the page itself. It knows what its
settings mean and calls `app` to read and write them; it never shells out.

**4. `SettingsWindow.qml`, four places:**

| Where | What |
| --- | --- |
| `sectionSource(id)` | `case "<id>": return "sections/<Thing>Section.qml"` |
| `pageTitles` | the page's name as the reader sees it |
| `navBlocks` | the sidebar item, or another page in an existing item's `pages` |
| `pageAvailable(id)` | only if the page can be absent — an application you may not have |

**5. Search.** `omacontrol search` learns which file holds which page **by
reading the `case` labels in `sectionSource`**. A page reachable only through
the `default` branch is one search cannot see. That is exactly what hid
Herdr's 25 settings.

## Check it, in this order

1. `bin/omacontrol search | jq 'keys'` — the new page id is there.
2. `bin/omacontrol search | jq '.["<id>"] | length'` — it found the labels.
3. `.claude/skills/omacontrol-testing/scripts/verify.sh` — the shell loads it.
4. Open the window and type the page's name into search — it should appear
   whatever its settings are called, because a page whose **name** matches is
   listed on its own.

## Gotchas

- **The heading is part of the match.** Rows read their heading off the
  `SettingGroup` above them. Without it a search for "blur" counts eleven
  settings and shows seven.
- **A page that declares no labels shows no number beside it.** That is
  correct, not a bug — it is listed because its name matched.
- **Rows named by the system say so through `NavCursor.searchText`.** A list
  of devices or networks has no labels in the source for the index to read.
- **The index is only as fresh as the state.** A device that appears while the
  window is open is searchable at the next read.
- **A page for an application you may not have** must answer `pageAvailable`,
  or it sits in the menu with nowhere to go. The binary is the test
  (`command -v`), never the config file: an application can be installed and
  never configured, and a config can outlive the thing it configured.
- **Only the open page is instantiated.** That is what keeps the window cheap,
  and it is why search reads the sources rather than asking the pages.
