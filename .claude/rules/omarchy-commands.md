---
paths:
  - "lib/*.sh"
  - "bin/*"
---

# Prefer Omarchy's commands

> **Read this when:** you are about to implement something Omarchy already does, or build a page over something the bar already shows.

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

