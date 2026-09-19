---
paths:
  - "lib/*.sh"
  - "bin/*"
---

# Other people's files

> **Read this when:** you are about to write to any file OmaControl did not generate — a Hyprland config, `shell.json`, `tmux.conf`, `options.lua`, `config.toml`, `.XCompose`.

## The one rule about other people's files

**Never parse and rewrite a hand-written config.** That is how a settings app
eats someone's setup. Every file falls into one of three patterns:

1. **Generated wholly by us** — `~/.config/hypr/omacontrol.lua`, rendered
   from our store (`~/.config/omarchy/omacontrol.json`); `omacontrol.conf` and a
   `source =` line are rendered instead for a setup still on `.conf`. Hyprland
   settings are applied live with `hyprctl eval` on a Lua config — **never
   `keyword`, which does nothing there** and says so on stderr while exiting 0;
   `hypr_apply_live` falls back to `keyword` only when there is no
   `hyprland.lua`. They are recorded in the generated file, which is loaded last
   so the user's own files still say what they wrote. It is created on the first write, not at
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

