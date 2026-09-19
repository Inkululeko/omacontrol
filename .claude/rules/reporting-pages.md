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

**A per-process CPU figure is a share of one core.** `top` calls a thread using
a whole core 100 %, which on sixteen cores is 6 % of the machine. The bars in
the table are scaled by the core count so they mean the same thing as the CPU
card above them.

## A poll asked for during a poll is owed

`pollInto` remembers a poll it could not start and runs it when the one in
flight finishes. Dropping it — the obvious guard, and the first version — costs
every action on every live page up to a full poll interval of staleness: mark a
headline read and the store is written at once, while the star stays put for
another five seconds because the poll that would have noticed was refused, and
the timer's own poll had already read the old value. The *command* is
remembered rather than merely a flag, so a reader that takes an argument (the
process sort) re-runs with the argument it was asked for.

This is the same shape as `refreshOwed` and `sliceOwed` on the state read, and
for the same reason.


## Three pages that report on the system

`packages`, `usage` and `about` follow the Disk and Processes pattern — poll,
never in the state document — with one addition each:

**Packages separates cheap from networked.** Counting what is installed is four
`pacman -Qq` calls and costs nothing, so it polls. Knowing what is *available*
is a database sync, so it is a button, cached, and the page says when it last
ran. `checkupdates` covers repositories only; an AUR-heavy machine would be
told it was up to date while a dozen packages waited, so `yay -Qua` is asked
too, behind the same `omarchy-pkg-aur-accessible` gate Omarchy's own updater
uses. Sizes come from `expac -S '%n\t%k'` — the name has to come back with the size
or there is nothing to key it by — 184 packages in a sixth of a second,
which is why there is no excuse for showing a count without its weight.

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

