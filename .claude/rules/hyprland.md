---
paths:
  - "lib/hypr.sh"
  - "lib/devices.sh"
  - "lib/setters.sh"
  - "lib/state.sh"
  - "sections/{Windows,Layout,Effects,Groups,Keyboard,Pointer}Section.qml"
---

# Hyprland: reading, applying, per-device

> **Read this when:** you touch `lib/hypr.sh`, `lib/devices.sh`, or anything that reads or writes a Hyprland option.

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


## Reading Hyprland in one call

`hypr_state` asks for every setting in a single `hyprctl --batch` and sorts the
answers out in jq. One call each was fine at a dozen settings and not at
seventy-odd: it took a second on its own, the window sat on "Loading" for
seconds, and — the part that actually misleads — every page rendered the
fallbacks written into its rows rather than the values Hyprland holds. If a
page shows suspiciously round numbers, suspect that before suspecting the page.


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

