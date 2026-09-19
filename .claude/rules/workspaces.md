---
paths:
  - "lib/workspaces.sh"
  - "lib/apps.sh"
  - "sections/{Workspaces,Apps}Section.qml"
  - "ui/AppRules.qml"
---

# Workspaces and window rules

> **Read this when:** you touch `lib/workspaces.sh`, `sections/WorkspacesSection.qml`, `sections/AppsSection.qml` or `ui/AppRules.qml`.

## The Workspaces page

An application bound to a workspace is a window rule: `o.window("slack",
{ workspace = "3" })`, the line people write at the foot of `hyprland.lua` by
hand. Ours go into the managed Lua under `.windowRules`, keyed by window class,
rendered in the same shape so the two read alike. A rule is an override, so a
row carries Remove rather than a reset; an off switch or an empty workspace
deletes the field rather than writing `false`, since `float = false` would pin
a window tiled against the user's own config.

**The class is the trap.** Slack's desktop entry says `StartupWMClass=Slack`
and its windows say `slack`, and a Hyprland match is a case-sensitive regex.
So `workspace_apps` lists desktop entries but takes the class from a running
window of the same name in any case when there is one, and lists running
classes with no entry at all. An application that has never run is bound by
its entry's class, which is the best guess there is.

Their own single-line `o.window("<class>", { ... })` rules are read, never
written, and shown as "set in your own config"; a value picked for the same
class lands in our file, which loads last and wins per property. A match given
as a table is about more than a class and is left alone. Removing a rule they
wrote comments the line out in place with a note, after `backup_once` and with
a `luac -p` check and restore — the same targeted edit a device block gets.

**The rest of a window rule is a short list, on purpose.** Beyond workspace
and how it shows, an application gets display, a floating size as a width and
height in percent of the screen plus a Centred switch (coordinates are for
Lua), pinned, no initial focus, idle
inhibit and no screen share. Opacity, blur, animation and the like are the
Effects page's, per application in Lua only, and groups and tags are left
alone. Pinned and placement only mean anything floating, so turning floating
off drops both rather than keeping a promise Hyprland ignores.

**Autostart is a desktop id, not a command.** "Start when you log in" writes
`o.launch_on_start("slack.desktop")` — Omarchy's own helper, launching through
uwsm by desktop entry id the way the launcher does — so the switch exists only
for an application with a desktop entry; a bare window class has no command
to start. Their own `o.launch_on_start("<id>.desktop")` lines are read, put
the application on the page, and are commented out on Remove with its window
rule. A bare command in their autostart is theirs to keep.

**Workspaces themselves are the second half of the page.** `.workspaceRules`
renders as `hl.workspace_rule({ workspace = "3", ... })`: display, default on
that display, persistent, default name, layout, and one "borderless" switch
that writes the five look rules together. Only a workspace with something set
gets a group; the rest wait behind a picker, so ten empty groups do not bury
the applications. Their single-line `hl.workspace_rule` calls are read and
commented out on remove, exactly as window rules are.

**A rule only governs windows that open after it.** So every write also
applies the rule in force to the windows of that class already open, through
`hyprctl eval` and the `hl.dsp.window.*` dispatchers with a `window =
"address:0x…"` target. Without this, "Shown as: Floating" left a fullscreen
Typora fullscreen — and Typora, like most Electron apps, remembers how it was
closed, so it came back fullscreen however the rule read. Two dispatcher traps:
`hyprctl dispatch <old syntax>` on a Lua config parses its argument as Lua and
fails — silently, if stderr is dropped — so nothing here uses it; and
`hl.dsp.window.float()` toggles whatever argument it is given, so it is sent
only to a window on the wrong side of the rule. `fullscreen_state` and `move`
do set rather than toggle.

