---
paths:
  - "sections/*.qml"
  - "ui/*.qml"
---

# Design

> **Read this when:** you add or change anything the reader sees: a page, a row, a group, a card, a heading, a note, a colour, a piece of copy.

## When the bar already shows the same thing

A page that duplicates a bar widget has to agree with it, or the two become
two answers to one question. Audio was a lesson in this: `pactl` lists every
sink in the graph, so the page offered four HDMI outputs with no cable in them
and a physical speaker sink sitting behind a tuning, under names like "Radeon
High Definition Audio Controller HDMI / DisplayPort 3 Output". The widget shows
two devices called "ALC285 Analog" and "HDMI 3".

The difference was not taste. `omarchy-audio-sink-availability` reports which
sinks have a live port and hides the one a speaker tuning fronts; the widget
labels a device by its own short nickname (`node.nick`) rather than the
sentence PulseAudio assembles. Both now feed this page too.

Before building a page over something the bar already shows, read the widget
and use the same source, the same filter, and the same labels.


## Design

The window is a settings app, so it follows what settings apps have settled on.

**Theme first, always.** The design this window is drawn from has a warm
palette of its own. What is taken from it is the *hierarchy* — which surface
sits on which, how far apart two greys are, what is a pill and what is a card —
and every one of those is expressed in `ui/Palette.qml` as an alpha over the
theme's own foreground or accent. So a Catppuccin desktop and a Gruvbox one
each get the design in their own colours. Never hardcode a colour in a page.

**Three surfaces and no more:** the window, the sidebar beside it, and the
cards on it. Anything finer stops being visible once a theme supplies the colours.

**One sidebar, in blocks, and no second column.** `navBlocks` holds
twenty-four destinations in four blocks: three unheaded at the top — Overview,
Network, Bluetooth, which is what people open this window for mid-task — then
Experience, System, and Apps & Packages. Every destination is on screen at
once. An item holding more than one page reveals those pages indented beneath
it while it is open, so the second level exists only where there is something
to put in it, and only for as long as you are there.

This replaced a rail of ten icons beside a list of that rail's pages, which
had replaced a flat list of twenty-six rows. Flat made every page one click
away and none of them findable — the eye has no landmarks in a list that long.
The rail fixed the landmarks and lost the names: you had to know which of ten
icons held Neovim before you could see that it existed. Blocks keep both.

**An icon on every item, and a fill on the open one.** The selected item is an
accent-filled rounded rectangle with its glyph and label struck from
`Palette.onAccent`. A sub-page is unfilled and marked instead by a small accent
tick bar at its left edge: a second fill one level in reads as a second
selection.

**The first ten items are on the number keys; the rest are not.** `itemWithKey`
flattens the blocks and takes `1`–`9` and `0`, which at rest reaches Overview
through Mouse & touchpad. Ten caps is what the legend can carry — fourteen
more would be keys nobody learns. Note that the flat list is the *filtered*
one, so the mapping shifts while a search is narrowing the sidebar.

**Alt+Up/Down walks the open item's pages, not the sidebar.** The sidebar is
already all on screen; the pages under an item are the only thing that is not.
The legend offers the pair only when the open item has more than one page.

**A search empties the sidebar rather than dimming it.** An item whose pages
all fail the filter is dropped, and a block that loses all its items goes with
it; what survives carries a match count. Dimming was right when the sidebar
was a rail of ten fixed landmarks — with twenty-four items it left a column of
rows you can see and cannot reach.

**The search box sits at the top of the sidebar.** It lived in the window
header on the argument that a search crosses every rail — but the rail is
gone, and what a search now narrows is this one column, directly beneath it.

**The crumb appears only where an item holds more than one page.** It is the
item's label, printed over the page name — worth saying for Bindings under
Keyboard and useless for Network under Network. "Overview / Overview" says
nothing twice, and a crumb that is always there stops being read.

**What has changed sits in the window header.** The count and "Undo all" are a
fact about the window, not about the page on screen: the live pages change
nothing this window tracks, and a count beside their name read as though it
were about them. So the count and what undoes it sit together, once.

**A heading, not a card — unless the group is one thing.** `SettingGroup` is
unframed by default: down a page of eight groups the edges were more chrome
than structure, and a heading large enough to be read as one separates just as
well. `framed: true` is for a group that is one *thing* being reported on —
the connection you are on, what needs attention — where the edge says where
the thing stops. Inside a frame the rows are inset by `pad`, and a row's
cursor band runs to the card's inside edges rather than stopping short of them.

**One table, everywhere rows are compared.** `DataTable` draws the mounts,
swap and the snapshots on Disk, the process list, the applications, both
package lists and both usage lists. A table and not a list of rows because the reader is
comparing down a column — which partition is fullest, what is eating the CPU —
and that only works if the figures line up. Actions go *under* the table and
act on the selected row: five rows each carrying four buttons is twenty
buttons, nineteen of which are about a row nobody is looking at.

**The Overview toggles are tiles, and a filled tile is on.** Four across, each
with a round icon badge and its switch on one line and the name and state
under them. Not rows: the question these answer is *which of these are on right
now*, asked of all four at once and often from across the desk, and a column of
rows answers it with four small knobs in a vertical line that have to be read
one at a time. The fill is the state; the switch is only the affordance, which
is also why the whole tile takes the click.

A grid of tiles goes in a plain `SettingGroup` — the tiles are the cards, and
a card around them is a border drawn twice and a padding paid for twice. That
is the default; `framed: true` is the thing you opt into.

**A wash over an accent fill is struck from `onAccent`, never from white.**
`Palette.onAccentWash(alpha)` exists because the badge and the switch track on
a filled tile were `Qt.rgba(1, 1, 1, 0.22)`, which is invisible on a light
accent. Nothing errors; the control just loses half of itself under half the
themes, which is the failure mode this whole palette is meant to prevent. The
same applies anywhere a control is drawn over an accent fill.

**Keycaps, at last.** The legend along the foot is drawn as keys. It was plain
text on the grounds that a row of boxes pulls the eye off the settings, and
that holds only if the caps are large or loud — small, low-contrast and all one
size, the bar reads as one band of chrome. It still *follows the cursor* rather
than listing everything, which the mockup did not: the keys that always apply,
plus whatever the row under the cursor answers to.

**Name a thing once.** A page called Bluetooth should not then contain a group
called Bluetooth containing a row called Bluetooth. If a heading and the thing
under it would carry the same word, the heading goes.

**A control that governs the whole page belongs in the header.** Pages can
declare `property Component headerControl` and `property string headerNote`;
the window renders the control beside the page name and the note under it. The
header once named the file a page writes to, which was a promise the pages
could not keep — Displays lands in two files on a laptop, Appearance in
whatever Omarchy's commands touch — and it said nothing about the setting the
reader was looking at. The Bluetooth adapter switch and its state live there.
Anything that governs only part of a page stays a row.

**Lead with what the page is for.** Network opens with the Wi-Fi switch and
the networks it finds, because choosing a network is why anyone comes here.
Address, gateway and band are about the network you already picked, so they sit
under Connection *after* the list rather than between the switch and it.

**Group by the question being asked, not by the data.** Bluetooth devices are
Connected, Paired and Nearby — three headings — because those answer *what am I
using*, *what do I own*, *what else is here*. One list sorted by state makes the
reader infer the boundaries from the buttons on each row.

**What belongs to a frame is stepped in from it.** A framed `SettingGroup`
insets its rows by `pad`, so membership is a matter of looking rather than of
reading. An unframed group insets nothing: its heading and its hairline are
already saying where it starts, and there is no edge for the rows to sit in
from.

**A handful of short choices go side by side, not in a dropdown.** `ChoiceRow`
wraps the kit's `ButtonGroup` from `qs.Ui`, so DNS providers are all visible at once. A dropdown is for lists that are long
(themes, fonts) or whose labels are sentences; opening one to discover there
were only four options is a wasted click.

**A row that sets its own `visible` must keep the search in it.** `NavRow`
binds `visible: !searchHidden`, and a page that writes `visible: <condition>`
replaces that binding outright — the row then stays on screen through every
search, which reads as the filter being broken rather than as one row opting
out. The form is always `visible: !searchHidden && <condition>`; a group uses
`!searchEmpty` the same way. It is invisible in review and obvious the moment
you type in the search box, which is how fourteen of them shipped at once.

**A heading earns its place or disappears.** `SettingGroup` renders no heading
when its title is empty, which is right for a page with a single group; the
page name is already the heading.

**Say what a setting does, never what it runs.** Notes and descriptions are for
the reader — "Off lets the terminal handle clicks, so links stay clickable",
not "runs omarchy-bar transparent toggle". Implementation belongs in code
comments and the README.

**A note that restates its own rows is noise.** "Paired — yours, but not
connected right now" tells the reader nothing the heading and the rows did not.
A note earns its place by adding a fact you cannot see: that an uninstalled app
gets set up when you pick it, that a bar widget still needs a slot in the bar.

**Don't repeat state that is visible below.** The header says whether Bluetooth
is on, not which devices are connected, and the Wi-Fi switch does not name the
network you are on — the list under both is already saying it, a few rows down.

**A page that watches something keeps itself current.** Network and Bluetooth
poll while they are the page on screen *and* the window is open
(`running: app.shown`), through a light `poll` subcommand that returns what is
known right now rather than re-reading the whole state. Bluetooth polls every
five seconds; Network runs two timers, two seconds for the link readings and
five for the list of networks. Nobody should have to press a button to see
what is in the room.

Discovery differs between the two: a Wi-Fi scan is a one-shot request that
NetworkManager rate-limits, while Bluetooth discovery is a *mode* the adapter
has to be held in. So the Bluetooth poll keeps a 30-second `bluetoothctl scan`
alive and lets it lapse once the polling stops — the page never has to clean up
after itself.

