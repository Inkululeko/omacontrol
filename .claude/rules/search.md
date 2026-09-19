---
paths:
  - "lib/menu.sh"
  - "lib/state.sh"
  - "SettingsWindow.qml"
---

# Search, and pages that may not exist

> **Read this when:** you add a page, rename one, or touch `search_index` in `lib/menu.sh`, `sectionSource` in `SettingsWindow.qml`, or `NavCursor.searchText`.

## Pages for applications you may not have

Tmux, Neovim and Herdr get a page each, and an application you do not have is
a page of settings with nowhere to go — so `pageAvailable()` drops it from the
menu, from the search counts and from Alt navigation, and steps off it if the
application goes away while its page is open.

**The binary is the test, not the config file.** An application can be
installed and never yet configured, and a config file can outlive the thing it
configured; only `command -v` answers the question actually being asked. Each
of the three reports it in its own state as `installed`.


## Search

Only the open page is instantiated, which is what keeps the window cheap and
what makes searching awkward: the window cannot ask a page it has not built
what it holds. `omacontrol search` reads the section sources instead and
returns every label, description and heading per page, keyed by the page ids
taken from `SettingsWindow.qml`'s own routing — so a page renamed or a setting
added is in the index without a second list to update. The function lives in
`lib/menu.sh`, not in `lib/state.sh`: `state.sh` only calls it
(`par_run searchsources search_index`) and merges its answer with what the
running system contributes.

The index arrives with the state, not from a call of its own, because half of
it is the state: a page that is a list of things — this keyboard, that
network, your bindings, the plugins you have — can only be described by the
running system, and `state.sh` has already asked. The section sources give the
rest. Rows named by the system say so through `NavCursor.searchText`.

Two things are deliberately *not* in it. Wi-Fi networks and Bluetooth devices
were, and a search box that finds the coffee shop you are sitting in is not a
search box for settings — it also meant every write anywhere in this window
waited on NetworkManager and bluetoothctl, which was 0.4 s of a 0.9 s state
read. Neither is in the state document at all now: their pages poll, and
nothing else asks. A page whose rows have no other source has to poll for
itself — the Wi-Fi list quietly had no poll of its own, because the state
document had always been refilling it.

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

