#!/usr/bin/env bash
# QML is compiled into the long-lived Quickshell process, so a .qml change
# that has not been through `omarchy restart shell` has not been seen working.
# The end of the turn is the last moment anyone can be told that.
#
# It asks **once per session**. The first version stamped a nudge file against
# the marker's mtime, which any further edit re-armed — so in an ordinary
# session (edit, blocked, explain, one more change, edit) it blocked nearly
# every turn, which is how a safety mechanism gets switched off. One sentence
# saying why a change is not being verified now ends the matter for good.
set -uo pipefail

marker="${XDG_RUNTIME_DIR:-/tmp}/omacontrol-unverified"
[ -s "$marker" ] || exit 0

payload=$(cat)
# If the harness tells us it is already re-entering because of this hook, stop.
[ "$(printf '%s' "$payload" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

session=$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)
nudge="$marker.nudged.${session:-nosession}"
[ -e "$nudge" ] && exit 0
touch "$nudge"

files=$(sort -u "$marker" | head -12 | tr '\n' ' ')
cat >&2 <<MSG
QML changed and the shell has not been restarted since: $files

QML is compiled into the running Quickshell process — it is not hot-reloaded,
and a page that fails to load leaves the window blank with no other sign. Run
  .claude/skills/omacontrol-testing/scripts/verify.sh
(it restarts the shell — the bar is dead for about seven seconds — and reports
what the journal said), or say plainly why this change is not being verified.
Either way, do not report it as done until one of those has happened. This is
asked once per session.
MSG
exit 2
