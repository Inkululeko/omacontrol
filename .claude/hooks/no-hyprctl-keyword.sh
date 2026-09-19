#!/usr/bin/env bash
# `hyprctl keyword` does nothing on a Lua config. It answers "keyword can't
# work with non-legacy parsers. Use eval." on stderr while still exiting 0, so
# the setting looks applied and is not — which is how two Displays settings
# shipped broken. Blocked rather than warned, because the failure is invisible
# at the call site: there is no error to notice.
#
# It matches the command *position*, not the text. The first version matched
# the raw string and so blocked `grep -rn 'hyprctl keyword' lib/`, `cat` of
# this very file, and `git add` of it — obstructing the audit while a variable
# walked straight past. Prefix with HYPRCTL_LEGACY_OK=1 if the target really
# is a .conf setup.
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$cmd" ] || exit 0

printf '%s' "$cmd" | python3 -c '
import re, sys
cmd = sys.stdin.read()
if "HYPRCTL_LEGACY_OK=1" in cmd:
    sys.exit(0)
for segment in re.split(r"\|\||&&|[|;&\n]", cmd):
    words = segment.split()
    while words and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", words[0]):
        words.pop(0)                       # leading VAR=value assignments
    if not words:
        continue
    if words[0].rsplit("/", 1)[-1] != "hyprctl":
        continue
    if "keyword" in words[1:]:
        sys.exit(2)
sys.exit(0)
' || {
  echo "hyprctl keyword does nothing on a Lua config — it prints its complaint on stderr and exits 0. Use: hyprctl eval 'hl.config({ ... })' (or hl.device / hl.monitor). Prefix the command with HYPRCTL_LEGACY_OK=1 to override." >&2
  exit 2
}
exit 0
