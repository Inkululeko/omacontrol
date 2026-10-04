---
paths:
  - "lib/{disk,processes,overview,packages,usage,about,news}.sh"
  - "lib/state.sh"
  - "SettingsWindow.qml"
  - "sections/{Disk,Processes,Overview,Packages,Usage,About}Section.qml"
---

# The pages that report rather than configure

> **Read this when:** you touch Overview, Disk, Processes, Packages, Usage or About — in `lib/` or in `sections/` — or you are about to add something to the state document that one of them could poll for instead.

## The three pages that are not settings

Overview, Disk and Processes report rather than configure, and that changes
where their data lives. **None of them is in the state document.** A state read
happens after every write anywhere in the window, and `df` on a machine with a
network mount — or two frames of `top` — would be paid for by every switch on
every other page. Each polls for itself instead, while it is the page on screen
and the window is open, exactly as Network and Bluetooth do.

`slicesSuffice` in `SettingsWindow.qml` names them, so a command of theirs
re-reads *nothing*: the page that asked for it polls, and it is the only thing
that has to hear back. Ending a process, mounting a stick or taking a snapshot
changes nothing this window holds. It now covers ten commands rather than
three — `overview`, `disk`, `processes`, `packages`, `apps`, `usage`, `news`
and `about`, plus `workspaces` and `display`, which are not reporting pages but
have the same property: what they change is not in the document.

`plugin` is the one that polls *and* keeps its slices. Switching a plugin on
changes `plugins` in the document, so it is not in `slicesSuffice`; what the
page reads about each plugin — its manifest, its size, what the marketplace
says — is a poll of its own. `pollFor` runs beside the slices rather than
instead of them. See `.claude/rules/bar-and-plugins.md`.

**Overview keeps no state of its own.** Every switch on it is Omarchy's —
night light, do not disturb, stay awake, dictation — asked on the poll and
relayed on the flip, side effects and all. Reading and flipping are not always
the same command: do not disturb is read with `omarchy-shell notifications
dndState` and flipped with `omarchy-toggle-notification-silencing`. That is what stops the page disagreeing with the bar,
which shows the same four things. Its "needs attention" list is two sources on
purpose: what only the shell can answer cheaply (how full `/boot` is, which
peripheral is nearly flat) comes from the reader, and what the window already
holds — its own version — is derived in the page rather than read again.

**An empty list is no list.** When nothing needs attention the whole section
goes, heading included — it is not replaced by a row saying so. A section that
reports its own emptiness takes up room on every good day to reassure the
reader on none of them, and the page already says it better: with nothing
wrong, the first thing under the title is the toggles, which is what anyone
opening this page wanted when nothing is wrong. When there *is* something, the
heading carries the count.

**What is not on that list, and why.** A display on a fractional scale was,
briefly. It is true, it is worth knowing once, and it is *permanent* — the
reader chose that scale and is not going to change it because a settings window
keeps mentioning it. A notice that cannot be resolved is a notice that trains
people to stop reading the list, which costs more than the one fact was worth.
The bar for this list is: something changed, or something is about to break,
and there is an action that ends it.

**A switch is only offered when it can work.** Installed is not the same as
usable: a voxtype with no model transcribes nothing, so the Dictation row asks
`voxtype status --extended --format json` — the same JSON the bar's indicator
reads — and reports itself unavailable when `model` is empty. Every switch on
the page drops out the same way rather than sitting there doing nothing. The
command is `voxtype record toggle`; there is no `voxtype toggle`, which is the
sort of thing that only shows up when someone tries the row.

**What is not on Overview, and why.** A package-update notice. Answering that
means `checkupdates`, which syncs a database over the network, and nothing in
this window may wait on the network. Omarchy's own update indicator already
says it.

**The Disk breakdown is not on the poll.** The only way to answer "what is
holding the space" is to walk directories, so it is its own subcommand, asked
once when the page opens. A walk that does not finish reports `null` rather
than what it had got to — a partial `du` is not a small number, it is a wrong
one — and the page says so instead of quietly showing a slice that is missing.

**A walk is not a read, and `OMACONTROL_READ_TIMEOUT` is not its budget.**
Five seconds is right for anything on a poll; a home directory of three
million files takes 13 seconds warm and 47 cold, so held to the read timeout
it *never* finished. The failure was silent in the worst way: Home reported
`null`, its 153 GB fell into the System slice by design, and the page showed
System at 246 GB on a machine whose system is 94 GB — with a "could not
measure" note that could never stop being true. `capture_for` and
`OMACONTROL_WALK_TIMEOUT` (120 s) are the walk's own budget. Nothing waits on
this read, so the only cost of the longer ceiling is that the page says
"Working out what is using the space" while it runs — which it has to, because
a headline figure with a gap under it for half a minute reads as a page that
has finished.

**The drive page answers what every machine can answer.** SMART needs the
drive to keep those figures and `smartctl` to run without a password, so the
Health panel is absent on most laptops — a card per drive, and Swap, are there
instead, and both come from `/proc` and `lsblk`. Busy is the figure that
actually answers "is the disk why this feels slow": a drive can sit at 100 %
busy while moving almost nothing, which is what thousands of small files look
like. Rates are divided by the *measured* elapsed time, because `sleep 0.2` is
a floor and not a promise.

**A card is titled by the thing, not described by it.** The drive card opens
the way the battery card does: the thing pictured, its name beside it, a badge
saying which one it is. Capacity, connection and solid-state-or-spinning are
facts that never move, so they sit in the grid under a label the reader can
find rather than in a line of clauses under the title. "260 GB used of 981 GB"
is the *bar's* caption, small and directly over it — a display-sized figure
there competed with the drive's own name for the top of the card. Free is in
the key as well as the bar, since the bar's last stretch was otherwise the one
unlabelled thing on the card and read as a gap rather than as space.

**The space belongs inside the drive's card.** "720 GB free" standing on its
own above the cards was a figure with no subject — on a machine with a second
drive nothing said which one it was about — and the page header repeated the
drive's name under it. The card carries all of it now and the header carries
nothing. Free is summed from the *filesystems* on the drive rather than taken
as capacity minus used: btrfs keeps metadata in reserve, so a 1.0 TB drive
with 259 GB used has 720 GB free and not 741, and the figure has to be the one
`df` gives because that is the one every other tool gives. The breakdown is
only drawn on the drive the system is on, since that is what it measures; any
other drive gets its used share in one piece.

**A card per drive, not a figure per machine.** A laptop with an SSD for the
system and a second disk for everything else is two answers to "is the disk
busy", and one figure covering both hides the drive that is grinding behind
the one that is idle. Each drive is a card in the shape the battery and the
connected network use — the thing's own name across the top, a badge saying
which drive it is, and the readings under a rule — because a heading outside
a box reads as a label for a separate block that happened to follow. The
sampling is still one pair of reads for the whole machine: `/proc/diskstats`
has every device in it. `zram` and loop devices are listed there and by
`lsblk` as disks, and are neither.

**There is no cache cleaner here, and there was very nearly one.** A "Safe to
delete" section was built and reverted: it found the caches on the machine,
measured them, and offered a Delete button behind a confirm. The mechanics
held up under review — the delete could not be raced into following a swapped
symlink, an id chose the paths so a caller could never name one, an unreadable
directory deleted nothing. What failed was the *judgement about what counts as
a cache*, twice in the same file that declared the rule: `~/.m2/repository`
looks exactly like a download cache and is also where `mvn install` puts a
developer's own jars, and an AUR helper's cache directory looks exactly like
build scrap and holds hand-edited PKGBUILDs.

That risk does not shrink with more careful review, which is the whole reason
this is written down. The catalogue is a standing bet that it stays right for
every tool every Omarchy user has, on every machine, as those tools change,
and one wrong entry deletes work that exists nowhere else — silently, at the
press of a button that promised the opposite. A settings window does not get
to take that bet on someone else's behalf. Reporting what is *using* space is
this page's job; deciding what may be destroyed is not.

The two things that survive it: the package cache and orphaned packages are
cleared from the Packages page, through Omarchy's own commands in a terminal
where the password prompt can happen; and a walk gets the walk budget, not the
read timeout.

**Mounts are one row per filesystem, not per mount point.** A btrfs subvolume
layout mounts one filesystem at four paths, and a row each made one drive read
as four that were somehow all the same size and all 26 % full. The filesystem
carries the figures; its other mount points are stepped in underneath with
their cells left empty, which is how a table says "part of that" and "already
counted" without a word. Unmount is not offered on one — unmounting a
subvolume pulls a directory out from under whatever is using it while the
drive stays mounted, which is not what the word means to a reader.

**`findmnt -no SOURCE /` is not a device.** On btrfs it prints
`/dev/mapper/root[/@]`, and every Omarchy install with snapshots is in that
shape — so `lsblk` was asked about `@]` and the SMART panel had quietly never
appeared on a machine that had smartctl. `disk_root_source` takes the suffix
off, once, for everything that asks.

**Two samples, not one.** `/proc/stat` holds totals since boot, so a single
read gives the average since the machine came up: on a six-day uptime, a number
that never moves. Both the overall figure and the per-core bars are the delta
between two reads a fifth of a second apart. For the process list it is `top -b
-n 2` and the *second* frame, because `ps` reports a process's lifetime average
and would rank the browser that pinned a core an hour ago above the one doing
it now.

**A per-process CPU figure is a share of the machine.** `top` calls a thread
using a whole core 100 %, which on sixteen cores is 6 % of the machine, so
`processes_cpu_by_pid` divides by the core count — the way btop shows it, and
the way the CPU card above means it, so the two are on the same scale. The
bars are on that scale too — CPU against the whole machine, memory against all
of it — and not against the heaviest row, which kept the top bar full whatever
it was using. They do
not add up to it: the card is a different fifth of a second, counts kernel
time, and includes the poll's own `top`, which the list leaves out.

**The top ten are counted by name and container, the tree by process.** Twenty
browser helpers are one browser in "Top processes", because the question there
is which program. The name is resolved the way the Omatop bar widget does it —
`MainThread` and a Nix `.foo-wrapped` are named by their first real argument — and grouping by the
container as well keeps the Node inside a container apart from the Node
outside it. Containers are found by cgroup scope, and `docker ps` is only
asked when a scope exists, so a machine with nothing running never wakes the
daemon. `ps` is read in fixed-width columns because a command name can hold a
space.

**Always ten rows, even on an idle machine.** Over a fifth of a second only
three or four processes register any CPU, and a list that was three rows one
poll and seven the next moved the whole tree under it every two seconds. The
rest of the ten are ranked by lifetime CPU time — `ps`'s figure, wrong for
"now" and right for breaking a tie at zero.

**The tree is in PID order, and the kernel's threads start folded.** It is
re-read every two seconds, and a row that jumps whenever its CPU does cannot
be clicked — the two lists above it are what rank. A folded row carries its
branch's totals — summed RSS, so shared pages count once per process, as in
btop — or folding a terminal would take everything running in it out
of the figures as well as out of the list. The selection is held by PID, not
by row, because processes come and go above the one picked. `kthreadd`'s three
hundred rows of zeros fold into one by default, as btop scrolls past them.

**The table's rows are slots that outlive a poll.** `DataTable` once handed the
row array straight to its Repeater, which rebuilt every row on every change —
and every row's `NavCursor` re-registered with the window, which copies and
re-sorts its row list per registration. A six-hundred-row tree re-read every
two seconds would have paid all of that on every poll. Rows are now a `ListModel` of slots that
only grow or shrink at the end, cells are keyed by column, the cursor is only
loaded into a navigable table, and the switch and button only into a cell that
holds one.

## A poll asked for during a poll is owed

`pollInto` remembers a poll it could not start and runs it when the one in
flight finishes. Dropping it — the obvious guard, and the first version — costs
every action on every live page up to a full poll interval of staleness: mark a
headline read and the store is written at once, while the star stays put for
another five seconds because the poll that would have noticed was refused, and
the timer's own poll had already read the old value. The *command* is
remembered rather than merely a flag, so a reader that takes an argument (the
package being looked at) re-runs with the argument it was asked for.

This is the same shape as `refreshOwed` and `sliceOwed` on the state read, and
for the same reason.


## Three pages that report on the system

`packages`, `usage` and `about` follow the Disk and Processes pattern — poll,
never in the state document — with one addition each:

**Packages separates cheap from networked.** What is installed, how much room
it takes and why each package is there is *one* read — `expac -Q '%m\t%w\t%n'`,
all 1339 in twenty milliseconds — so the counts, the total on disk and the
list of the biggest all come off it and it polls. That replaced four
`pacman -Qq | wc -l` calls that answered less. Knowing what is *available* is a
database sync, so it is a button, cached, and the page says when it last ran.
`checkupdates` covers repositories only; an AUR-heavy machine would be told it
was up to date while a dozen packages waited, so `yay -Qua` is asked too,
behind the same `omarchy-pkg-aur-accessible` gate Omarchy's own updater uses.
Download sizes come from `expac -S '%n\t%k'` — the name has to come back with
the size or there is nothing to key it by — 184 packages in a sixth of a
second, which is why there is no excuse for showing a count without its weight.

**Without expac there are no sizes, and the page says nothing rather than
zero.** The fallback knows the names and not the bytes, and a list of forty
packages each reading "0 B" answers "what is taking the room" wrongly instead
of declining to answer. `largest` comes back empty, and the section goes.

**The one package the reader opened is its own read.** `packages info <name>`
is asked when a row is opened, never on the poll: the list already carries the
name, the size and the reason, and the rest — what it is, what needs it — is
only ever wanted for the one on screen. The drill-in is the Apps page's shape,
carried by `headerTitle` / `headerBack` / `headerBackTriggered`, so it needs no
route of its own.

**A header note is not the place for someone else's prose.** The window draws
it as a bare `Text` on the page title's baseline — no width, no elide, and
nothing clipping between it and the panel edge. That is right for the short
qualifiers the pages author themselves ("running now"), and wrong for a
package description: ninety-two of the 1339 here run past eighty characters
and would paint out through the side of the window. It goes in the group's
`note`, which has a width and wraps.

**`omarchy-update` must have a terminal, and it is the one command here that
hangs rather than fails without one.** It re-execs under `script` and then
asks `gum confirm`; detached, that prompt is drawn into a pty nobody is
attached to and waits for a keypress that can never come — so the update sits
for ever holding the Omarchy update lock and every later update is told one is
already running. `omarchy-launch-floating-terminal-with-presentation`, exactly
as the bar's own update widget and the Omarchy menu do it. There is no
snapshot button beside it either: `omarchy-update` takes one itself, after
pruning the cache, because the cache is on the snapshotted subvolume and
pruning afterwards frees nothing until that snapshot ages out.

**The removal picker offers what you chose, not everything.**
`omarchy-pkg-remove` builds its finder from `yay -Qqe` — 238 packages here,
not 1339 — so the row that opens it says "the ones you chose". The table above
it lists dependencies too, on purpose, since a 928 MB dependency is still the
answer to where the room went; promising the picker would find one is the kind
of copy that sends a reader looking for something that was never there.

**Agent usage computes nothing.** `omarchy-agent-usage-<provider>` already
collects the whole picture — local transcripts, the provider's authoritative
rate limits, the fallbacks — and Omarchy's agents panel reads exactly that
record. A second opinion about someone's rate limits is worse than none. What
the page adds is tokens instead of messages (a message is not a unit of
anything comparable) and bars scaled to the busiest row rather than to a
ceiling nobody set.

**About prefers `fastfetch --format json`** to reading a dozen files under
`/sys`, for the same reason everything here prefers Omarchy's commands: it
already knows that a laptop's model is a DMI family plus an SKU, and that a
machine can have two GPUs. "Copy as text" exists because the moment anyone
needs these answers is the moment they least want to go looking.


## Watching instead of asking

Two pages follow the system rather than re-reading it. Audio follows
`pactl subscribe`, because mute and volume belong to the server and the media
keys, the bar and every other panel move them. Power follows three signals at
once — the profile daemon over D-Bus, UPower for the battery, and inotify on
the files `omarchy-powerprofiles-set` writes — because the bar's power plugin,
the menu and the daemon all move the profile.

Both run only while their page is open, and both drain a burst of events
before re-reading, or one key press costs four reads. The monitors are killed
by an EXIT trap *and* by a watchdog on the reader, since neither notices the
page closing on its own.

Every other page is only as fresh as the last state read. Change a theme
elsewhere and this window shows the old one until something makes it read
again — worth knowing before chasing a "stale value" bug that is not one.

