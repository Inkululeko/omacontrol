#!/usr/bin/env bash
# The whole of "is it done": the manifest still validates, the syntax holds,
# the shell comes back, the window opens, and the journal has nothing to say
# about us.
#
# The since-stamp is taken before the restart rather than after, because a QML
# error is printed while the shell is coming up — a window measured from
# afterwards misses exactly the errors it was opened to find.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../../../.." && pwd)
cd "$root" || exit 1

fail=0
step() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

step "manifest"
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin validate . || fail=1
else
  echo "omarchy not on PATH — skipped"
fi

step "shell syntax"
for f in bin/omacontrol bin/omacontrol-migrate lib/*.sh; do
  [ -e "$f" ] || continue
  bash -n "$f" || { echo "  ^ $f"; fail=1; }
done
echo "checked $(ls lib/*.sh 2>/dev/null | wc -l) modules and 2 scripts"

step "qmllint (Qt 6)"
"$here/lint-qml.sh" || fail=1

since=$(date '+%Y-%m-%d %H:%M:%S')

step "restart shell — the bar is dead for about seven seconds"
omarchy restart shell || fail=1
sleep 8

step "open the window"
omarchy-shell omacontrol show >/dev/null 2>&1
sleep 2
# The layer existing is not the same as a page having drawn. A QML error
# leaves the window blank with no other sign, and a blank window is a layer
# with the same namespace and nothing in it — so the size is what is asked.
geom=$(hyprctl layers -j 2>/dev/null \
       | jq -r '[..|objects|select(.namespace?=="omacontrol")][0] | if .==null then "" else "\(.w) \(.h)" end')
if [ -z "$geom" ]; then
  echo "NOT UP — the window did not open at all"
  fail=1
else
  set -- $geom
  if [ "${1:-0}" -gt 200 ] && [ "${2:-0}" -gt 200 ]; then
    echo "the omacontrol layer is up and drawn, ${1}x${2}"
  else
    echo "UP BUT EMPTY — the layer is ${1}x${2}; a page that fails to load looks exactly like this"
    fail=1
  fi
fi

step "journal since $since"
log=$(journalctl --user --since "$since" --no-pager 2>/dev/null \
      | grep -iE 'omacontrol|qml|binding loop|unable to assign|cannot assign|not a type|non-existent property|TypeError|ReferenceError|case mismatch')
[ -n "$log" ] && printf '%s\n' "$log" || echo "(nothing)"

# Every one of these has shipped here and none of them contains the word
# "error": a binding loop, an undefined reaching a QString, a page that did
# not load, and the case-mismatch message Quickshell gives for an ambiguous
# import. Grepping for "error" alone was how the first version of this passed
# a broken build.
if printf '%s' "$log" | grep -qiE \
   'error|binding loop|unable to assign|cannot assign|failed to load|not a type|non-existent property|TypeError|ReferenceError|is not a function|is not defined|\[undefined\]|case mismatch'; then
  fail=1
fi

step "verdict"
if [ "$fail" -eq 0 ]; then
  echo "clean — the change has been seen working"
  rm -f "${XDG_RUNTIME_DIR:-/tmp}/omacontrol-unverified"
else
  echo "NOT clean — see above. This change is not done."
fi
exit "$fail"
