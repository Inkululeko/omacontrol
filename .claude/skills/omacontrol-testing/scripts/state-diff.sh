#!/usr/bin/env bash
# The state document is the whole contract between the shell side and the
# window, so a refactor that changes it by one key has changed behaviour
# whether or not anyone meant to. Captured before and compared after, with the
# fields that move on their own taken out first — otherwise the clock alone
# reports a difference every time.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
base="${XDG_RUNTIME_DIR:-/tmp}/omacontrol-state-baseline.json"

# The clock, the battery and anything stamped with when it was last asked.
# Kept here rather than in the caller so capture and compare cannot disagree.
stable() {
  "$root/bin/omacontrol" state 2>/dev/null \
    | jq -S 'del(.datetime.now, .power, .pluginUpdates, .selfUpdate)'
}

case "${1:-compare}" in
  capture)
    stable > "$base" || exit 1
    git -C "$root" rev-parse --short HEAD 2>/dev/null > "$base.rev"
    printf 'baseline: %s (%s bytes, %s top-level keys)\n' \
      "$base" "$(stat -c%s "$base")" "$(jq 'keys|length' "$base")"
    ;;
  compare)
    [ -s "$base" ] || { echo "no baseline — run: /state-diff capture" >&2; exit 1; }
    # A baseline with no provenance is worse than none: compared against one
    # taken days ago at another commit, "identical" means nothing.
    printf 'baseline taken %s at %s (now %s)\n\n' \
      "$(date -d "@$(stat -c%Y "$base")" '+%H:%M %d %b')" \
      "$(cat "$base.rev" 2>/dev/null || echo 'unknown rev')" \
      "$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo 'unknown rev')"
    now=$(mktemp); stable > "$now"
    if diff -u "$base" "$now" > "$now.diff"; then
      echo "identical to the baseline"
      rm -f "$now" "$now.diff"
    else
      printf '%s differing lines:\n\n' "$(grep -cE '^[+-]' "$now.diff")"
      head -120 "$now.diff"
      echo
      echo "(full diff: $now.diff)"
      exit 1
    fi
    ;;
  *) echo "usage: state-diff.sh capture|compare" >&2; exit 2 ;;
esac
