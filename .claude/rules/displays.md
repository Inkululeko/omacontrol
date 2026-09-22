---
paths:
  - "lib/monitors.sh"
  - "sections/DisplaysSection.qml"
  - "ui/DisplayCanvas.qml"
  - "ui/displays.js"
---

# Displays

> **Read this when:** you touch `lib/monitors.sh`, `sections/DisplaysSection.qml`, `ui/DisplayCanvas.qml` or `ui/displays.js`.

## Why a display is written down as well as applied

A display is unplugged and plugged back in, and Hyprland matches its monitor
rules again on every connect. So a resolution or a scale set on the Displays page becomes an
`hl.monitor` call in the managed file, and stays there while the display is
away so it is in force again the moment it is plugged back in.

**A display is only set up while it is in front of you.** There was a row for
typing the name of one that is not — the model, or a connector — and it asked
the reader to know how Hyprland spells a screen they cannot see, to configure
a resolution nothing could list, against an identity that was a guess until
the display finally arrived to prove it wrong. A display that has *been*
configured still keeps its group while it is unplugged, which is the half of
this worth having. `hyprctl keyword monitor`
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

**The whole of a monitor rule, and one place that renders it.** Beyond
resolution and scale a display carries a refresh rate, a rotation, variable
refresh, HDR, a mirror and a position — and two of those are not written the
way they are stored. `disabled` is the *whole* rule (a display that is off has
no mode or position to be given), and HDR is two Hyprland keys, `cm = "hdr"`
and `bitdepth = 10`. That translation lives in `MONITOR_FIELDS_JQ` and nowhere
else. It had to: the live apply and the generated file each rendered the store
their own way, and the file wrote `hdr = true`, which Hyprland does not know —
so the switch worked until the next reload and then quietly did not.

A rule of ours **replaces** Omarchy's rather than merging with it, so every
write fills in what the user did not set from what the display is doing now
(`monitor_in_force`). Position is the exception: pinning coordinates nobody
asked for would freeze a layout that currently follows whatever is plugged in,
so it joins the rule only once a display has actually been dragged. A display
that is off reports its mode as `0x0@60`, which is not a resolution and must
never reach a rule — it reads as `preferred` instead.

**The arrangement is a picture because the question is one.** "Is the laptop
left of the monitor" cannot be answered from two pairs of coordinates. Dragging
snaps to the neighbours' edges, pushes out of any overlap along the cheapest
axis, and then *closes whatever gap is left* — that last step is the one worth
keeping: Hyprland will lay out two displays with a hole between them, and the
pointer then cannot cross. The geometry is in `ui/displays.js` so it can be
read, and tested, without a compositor. The approach is Fluffet's
`omarchy-advanced-displays` (MIT).

**Brightness is a reading, not a setting.** It is moved by the media keys and
Omarchy's own OSD, and on a desktop monitor asking means a DDC/CI round trip
over the video cable — two thirds of a second cold, which is not a price every
write on every other page should pay. So it is not in the state document: the
Displays page polls `display brightness` while it is the page on screen, the
way Network and Bluetooth do, and `omarchy-brightness-display` is what answers,
because it already knows that a laptop panel is the kernel backlight and
everything else is DDC.

**A switch is only offered when it can work.** HDR appears only for a display
whose EDID claims it, and the variable-refresh row shows the range the EDID
gives. Both come from `di-edid-decode`, which exits non-zero over a warning in
an EDID most displays ship with, having printed everything asked of it — so
the output decides whether it worked, not the status.

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

**And turning it off is not ours either.** `omarchy-hyprland-monitor-internal
on|off` writes the rule that disables the panel into Omarchy's own toggles
directory, and the writing-down is the point: the clamshell watcher and
`omarchy-hw-recover-internal-monitor` clear that file again the moment the
external display goes away, so a lid closed on a dock is never left with no
screen at all. A `disabled = true` of ours had no way back — the panel stayed
dark through the undock and the next boot, with nothing on screen to turn it on
with. So the switch calls their command, our own `disabled` is dropped from the
store rather than left to fight it, and the `require` in `hyprland.lua` sits
above `require("default.hypr.toggles")` so their rule is the one read last.
Where that require is not there — a setup still on `.conf` — the toggle would
write a file nothing reads, so our own rule goes in instead.

**Most of what the store holds is not a setting**, only what is needed to say
what changed and put it back: `hypr` and `hyprOriginal` (Hyprland keys we
override and what they were), `written` (pre-change values for settings living
in other people's configs), `devices`, `monitors`, `bindings`, and `extras`
(animation speed, full opacity). The exceptions are the things that exist
nowhere else because nothing else owns them: `windowRules` and `workspaceRules`
(the Workspaces page), `barHidden` (a disabled widget's whole object and where
it sat), `newsRead` / `newsSeeded`, `dismissed`, and `monitorsSchema`. Delete
the store and no *setting* is lost — but those go with it.

